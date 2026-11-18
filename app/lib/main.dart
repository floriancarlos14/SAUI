import 'package:flutter/material.dart';

void main() => runApp(const SauiApp());

const bg = Color(0xFF101018);
const panel = Color(0xFF1B1B29);
const accent = Color(0xFF9B8CFF);

class Track {
  final String title, artist, genre;
  final Color color;
  const Track(this.title, this.artist, this.genre, this.color);
}

const tracks = <Track>[
  Track('Neon Dreams', 'Luna.exe', 'Synth Pop', Color(0xFF6547A8)),
  Track('After the Rain', 'Kairo', 'R&B', Color(0xFF276B72)),
  Track('Paper Moons', 'Mira Sol', 'Indie', Color(0xFF9B634E)),
  Track('Electric Heart', 'Nova 808', 'Electronic', Color(0xFF3C5795)),
  Track('Sa Dulo ng Gabi', 'Araw AI', 'OPM', Color(0xFF8A527B)),
  Track('Golden Hourglass', 'The Daydreams', 'Pop', Color(0xFF8B713D)),
];

class SauiApp extends StatelessWidget {
  const SauiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SAUI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const SauiHome(),
  );
}

class SauiHome extends StatefulWidget {
  const SauiHome({super.key});
  @override
  State<SauiHome> createState() => _SauiHomeState();
}

class _SauiHomeState extends State<SauiHome> {
  int tab = 0;
  Track? selected;
  String query = '';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void chooseTrack(Track track) => setState(() => selected = track);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homePage(),
      _searchPage(),
      _libraryPage(),
      _createPage(),
      _profilePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('SAUI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _notice('Notifications will appear here when accounts are connected.'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(child: IndexedStack(index: tab, children: pages)),
        if (selected != null) _miniPlayer(selected!),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF171722),
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Your Library'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Create'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _homePage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
    children: [
      const Text('Your sound. Your universe.', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Discover music made with AI.', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 22),
      Wrap(spacing: 8, runSpacing: 8, children: ['All', 'Music', 'Podcasts', 'AI Originals'].map((x) =>
        ActionChip(label: Text(x), onPressed: () => _notice('$x category selected.'))).toList()),
      const SizedBox(height: 22),
      _sectionTitle('Made for you', 'Based on your listening'),
      const SizedBox(height: 12),
      SizedBox(height: 190, child: ListView(scrollDirection: Axis.horizontal, children: [
        _featureCard('Daily Mix', 'A mix of sounds picked for you', const Color(0xFF57478C), Icons.graphic_eq),
        _featureCard('AI Discover', 'Find your next favorite', const Color(0xFF28666B), Icons.auto_awesome),
        _featureCard('Fresh Drops', 'New music from creators', const Color(0xFF88513E), Icons.new_releases),
      ])),
      const SizedBox(height: 26),
      _sectionTitle('Trending on SAUI', 'Explore what listeners love'),
      const SizedBox(height: 8),
      ...tracks.take(5).map((t) => _trackTile(t)),
      const SizedBox(height: 22),
      _sectionTitle('New releases', 'Recently shared by creators'),
      const SizedBox(height: 8),
      ...tracks.reversed.take(3).map((t) => _trackTile(t)),
      const SizedBox(height: 16),
      _prototypeNote(),
    ],
  );

  Widget _searchPage() {
    final found = tracks.where((t) => ('${t.title} ${t.artist} ${t.genre}').toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Search', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      TextField(
        controller: searchController,
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Songs, artists, genres...',
          prefixIcon: const Icon(Icons.search),
          filled: true, fillColor: panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 22),
      _sectionTitle(query.isEmpty ? 'Browse all' : 'Search results', '${found.length} results'),
      const SizedBox(height: 8),
      if (query.isEmpty)
        Wrap(spacing: 10, runSpacing: 10, children: ['Pop', 'Hip-Hop', 'R&B', 'Electronic', 'Rock', 'OPM', 'Jazz', 'Lo-fi'].map((g) =>
          SizedBox(width: 155, height: 90, child: _genreCard(g))).toList()),
      ...found.map(_trackTile),
      if (found.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No matches yet.', textAlign: TextAlign.center)),
      _prototypeNote(),
    ]);
  }

  Widget _libraryPage() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Your Library', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 16),
    Wrap(spacing: 8, children: [
      FilterChip(label: const Text('Playlists'), selected: true, onSelected: (_) {}),
      FilterChip(label: const Text('Artists'), selected: false, onSelected: (_) => _notice('Followed artists will appear here.')),
      FilterChip(label: const Text('Albums'), selected: false, onSelected: (_) => _notice('Saved albums will appear here.')),
    ]),
    const SizedBox(height: 18),
    _libraryItem(Icons.favorite, 'Liked Songs', 'Your favorite tracks', accent),
    _libraryItem(Icons.history, 'Recently Played', 'Your listening history', const Color(0xFF3E7890)),
    _libraryItem(Icons.queue_music, 'My Playlist', 'Create and organize playlists', const Color(0xFF9A7048)),
    const SizedBox(height: 18),
    _sectionTitle('Suggested for your library', 'Discover more'),
    ...tracks.take(3).map(_trackTile),
    _prototypeNote(),
  ]);

  Widget _createPage() => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Create on SAUI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    const Text('Make music, share your work, and grow an audience.', style: TextStyle(color: Colors.white60)),
    const SizedBox(height: 22),
    _toolCard(Icons.upload_file, 'Upload a song', 'Publish an original AI music track', () => _notice('Upload flow is the next feature to connect.')),
    _toolCard(Icons.mic, 'Voice conversion', 'Transform vocals with a voice you have permission to use', () => _notice('Your existing voice-conversion tool will live here.')),
    _toolCard(Icons.auto_awesome, 'AI Music Generator', 'Create a new song from an idea', () => _notice('AI music generation is planned as a separate tool.')),
    _toolCard(Icons.album, 'Create an album', 'Group your tracks into a release', () => _notice('Album publishing is planned for the creator tools.')),
    const SizedBox(height: 18),
    _sectionTitle('Creator tools', 'For artists'),
    _libraryItem(Icons.analytics_outlined, 'Creator analytics', 'Streams, listeners and engagement', const Color(0xFF476D9B)),
    _libraryItem(Icons.account_balance_wallet_outlined, 'Earnings', 'Track eligible revenue and payouts', const Color(0xFF477D69)),
    _prototypeNote(),
  ]);

  Widget _profilePage() => ListView(padding: const EdgeInsets.all(18), children: [
    const CircleAvatar(radius: 42, backgroundColor: panel, child: Icon(Icons.person, size: 42)),
    const SizedBox(height: 14),
    const Text('Your SAUI profile', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 5),
    const Text('Sign-in and artist identity will be connected in the account milestone.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
    const SizedBox(height: 22),
    _toolCard(Icons.person_add_alt_1, 'Create account / Sign in', 'Build your listener or creator profile', () => _notice('Account registration is not connected yet.')),
    _toolCard(Icons.workspace_premium, 'SAUI Premium', 'Ad-free listening and premium features', () => _notice('Premium plans and billing will be added after the core platform.')),
    _toolCard(Icons.settings_outlined, 'Settings', 'Playback, privacy and account settings', () => _notice('Settings will appear here.')),
    _prototypeNote(),
  ]);

  Widget _sectionTitle(String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ])),
      TextButton(onPressed: () => _notice('More — coming with the connected catalog.'), child: const Text('See all')),
    ],
  );

  Widget _featureCard(String title, String subtitle, Color color, IconData icon) => Container(
    width: 155, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: .48)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, size: 30), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(subtitle, maxLines: 2, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    ]),
  );

  Widget _genreCard(String genre) => InkWell(
    onTap: () { setState(() { query = genre; searchController.text = genre; }); },
    child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
      child: Align(alignment: Alignment.bottomLeft, child: Text(genre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
  );

  Widget _trackTile(Track track) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 3),
    leading: _cover(track, 48),
    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${track.artist}  •  ${track.genre}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
    trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _notice('Track options will be available when songs are published.')),
    onTap: () => chooseTrack(track),
  );

  Widget _cover(Track t, double size) => Container(
    width: size, height: size, decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(9)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 26),
  );

  Widget _libraryItem(IconData icon, String title, String subtitle, Color color) => ListTile(
    leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)), child: Icon(icon)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    onTap: () => _notice('$title will be connected to your account.'),
  );

  Widget _toolCard(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
    color: panel, margin: const EdgeInsets.only(bottom: 11),
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: CircleAvatar(backgroundColor: accent.withValues(alpha: .18), child: Icon(icon, color: accent)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      trailing: const Icon(Icons.chevron_right), onTap: onTap,
    ),
  );

  Widget _miniPlayer(Track track) => Container(
    margin: const EdgeInsets.fromLTRB(8, 0, 8, 7), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFF343047), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      _cover(track, 38), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(track.artist, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ])),
      IconButton(onPressed: () => _notice('Audio playback will be enabled when the streaming service is connected.'), icon: const Icon(Icons.play_arrow)),
      IconButton(onPressed: () => setState(() => selected = null), icon: const Icon(Icons.close, size: 19)),
    ]),
  );

  Widget _prototypeNote() => const Padding(
    padding: EdgeInsets.only(top: 22, bottom: 10),
    child: Text('SAUI platform preview: sample catalog and navigation only. Accounts, real audio streaming, uploads, subscriptions and creator payouts are not connected yet.',
      textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
  );

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}
