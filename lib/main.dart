import 'dart:convert'; // Permet de convertir en JSON (sauvegarde locale)

import 'package:english_words/english_words.dart'; // Génère des mots aléatoires
import 'package:flutter/material.dart'; // Widgets Flutter
import 'package:flutter/services.dart'; // Gestion orientation écran
import 'package:provider/provider.dart'; // Gestion d'état global
import 'package:shared_preferences/shared_preferences.dart'; // Stockage local

void main() {
  // Nécessaire pour utiliser du code async avant runApp (ex: SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized();

  // Autorise toutes les orientations d'écran
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(MyApp()); // Lance l'application
  });<
}

/* ============================================================
   APP PRINCIPALE
============================================================ */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // On injecte l'état global dans toute l'app
      create: (context) => MyAppState(),

      child: MaterialApp(
        title: 'Namer App',

        // Thème global
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),

        home: MyHomePage(), // Page principale
      ),
    );
  }
}

/* ============================================================
   ETAT GLOBAL (TRÈS IMPORTANT POUR LE CONTROLE)
============================================================ */

class MyAppState extends ChangeNotifier {
  var current = WordPair.random(); // Mot actuel

  late List<WordPair> favorites; // Liste des favoris
  var initialized = false; // Evite de charger plusieurs fois

  // Initialisation des données depuis le stockage local
  Future<void> init() async {
    if (initialized) return;

    final storage = await SharedPreferences.getInstance();
    final data = storage.getString('favorites');

    if (data == null) {
      favorites = <WordPair>[];
    } else {
      favorites = _wordPairsFromJson(data);
    }

    initialized = true;
  }

  // Génère un nouveau mot
  void getNext() {
    current = WordPair.random();
    notifyListeners(); // Met à jour l'UI
  }

  // Ajoute ou enlève un favori
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }

    _saveToStorage(); // Sauvegarde locale
    notifyListeners();
  }

  // Supprime un favori
  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    _saveToStorage();
    notifyListeners();
  }

  // Convertit liste → JSON
  static String _wordPairsToJson(List<WordPair> pairs) {
    return json.encode(
      pairs.map((pair) => {
            'first': pair.first,
            'second': pair.second,
          }).toList(),
    );
  }

  // Convertit JSON → liste
  static List<WordPair> _wordPairsFromJson(String data) {
    final decoded = json.decode(data) as List<dynamic>;

    return decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return WordPair(map['first'], map['second']);
    }).toList();
  }

  // Sauvegarde dans SharedPreferences
  Future<bool> _saveToStorage() async {
    final storage = await SharedPreferences.getInstance();
    return await storage.setString('favorites', _wordPairsToJson(favorites));
  }
}

/* ============================================================
   PAGE GENERATEUR
============================================================ */

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Observe l'état global (rebuild auto si changement)
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    // Choix de l'icône selon favori ou non
    IconData icon = appState.favorites.contains(pair)
        ? Icons.favorite
        : Icons.favorite_border;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),

          SizedBox(height: 10),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton "like"
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text("J'aime"),
              ),

              SizedBox(width: 10),

              // Bouton suivant
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Suivant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   PAGE FAVORIS
============================================================ */

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    // Aucun favori
    if (appState.favorites.isEmpty) {
      return Center(child: Text('Aucun favori pour le moment.'));
    }

    // Liste des favoris
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Tu as ${appState.favorites.length} favoris :',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        // Génère chaque ligne
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),

            // Bouton supprimer
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                appState.removeFavorite(pair);
              },
            ),
          ),
      ],
    );
  }
}

/* ============================================================
   PAGE PRINCIPALE AVEC NAVIGATION
============================================================ */

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0; // Onglet sélectionné
  Future<void>? initializer; // Initialisation async

  @override
  void initState() {
    super.initState();

    // Lance le chargement des favoris
    var appState = context.read<MyAppState>();
    initializer = appState.init();
  }

  @override
  Widget build(BuildContext context) {
    // Choix de la page
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError();
    }

    // Attend que les données soient chargées
    return FutureBuilder(
      future: initializer,

      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }

        // Responsive (mobile / desktop)
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 450) {
              // VERSION MOBILE
              return Scaffold(
                body: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),

                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: selectedIndex,

                  onTap: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },

                  items: [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Accueil',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.favorite),
                      label: 'Favoris',
                    ),
                  ],
                ),
              );
            } else {
              // VERSION DESKTOP
              return Scaffold(
                body: Row(
                  children: [
                    SafeArea(
                      child: NavigationRail(
                        selectedIndex: selectedIndex,

                        onDestinationSelected: (value) {
                          setState(() {
                            selectedIndex = value;
                          });
                        },

                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(Icons.home),
                            label: Text('Accueil'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.favorite),
                            label: Text('Favoris'),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: page,
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }
}

/* ============================================================
   WIDGET AFFICHAGE MOT
============================================================ */

class BigCard extends StatelessWidget {
  const BigCard({super.key, required this.pair});

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    // Style du texte
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,

      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: pair.asPascalCase,
        ),
      ),
    );
  }
}