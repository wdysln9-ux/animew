import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/hive/safe_box.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../notify/notifications_screen.dart';
import '../schedule/schedule_screen.dart';
import '../home/explore_screen.dart';
import '../watch_together/ui/watch_party_lobby_screen.dart';
import 'menu_tools_screen.dart';
import 'menu_forum_screen.dart';
import 'menu_social_screen.dart';
import 'menu_catalog_tools_screen.dart';
import 'menu_personal_list_screen.dart';
import 'menu_relations_screen.dart';
import 'menu_polls_screen.dart';
import 'menu_messages_screen.dart';
import 'menu_recommendation_match_screen.dart';

enum _MenuGroup { community, fun, anime }
class _MenuFeature {
  const _MenuFeature(this.id,this.title,this.description,this.group,this.icon,{this.url,this.service});
  final String id,title,description;
  final _MenuGroup group;
  final IconData icon;
  final String? url,service;
}
const _features = <_MenuFeature>[
  _MenuFeature('feed','Feed','Aktivitas AniList pengguna: mulai menonton, menyelesaikan anime, dan perubahan status.',_MenuGroup.community,Icons.dynamic_feed_rounded),
  _MenuFeature('forum','Forum','Diskusi anime dan manga, thread, komentar, balasan, dan membuat thread.',_MenuGroup.community,Icons.forum_rounded),
  _MenuFeature('messages','Pesan','Ruang percakapan pribadi dengan pengguna lain.',_MenuGroup.community,Icons.chat_bubble_rounded),
  _MenuFeature('notifications','Notifikasi','Pemberitahuan aktivitas, komentar, balasan thread, dan interaksi akun.',_MenuGroup.community,Icons.notifications_rounded),
  _MenuFeature('users','Pengguna','Jelajahi profil AniList, daftar anime, statistik, dan aktivitas pengguna.',_MenuGroup.community,Icons.people_alt_rounded),
  _MenuFeature('polls','Polling','Buat dan ikuti voting anime, karakter favorit, dan topik komunitas.',_MenuGroup.community,Icons.poll_rounded),
  _MenuFeature('chess','Catur','Bermain catur online, mencari lawan acak, atau mengundang teman.',_MenuGroup.fun,Icons.grid_4x4_rounded,url:'https://lichess.org',service:'Lichess'),
  _MenuFeature('shorts','Short','Jelajahi video pendek vertikal dari YouTube.',_MenuGroup.fun,Icons.smart_display_rounded,url:'https://www.youtube.com/shorts',service:'YouTube'),
  _MenuFeature('guess','Tebak Karakter','Tebak karakter dari gambar, petunjuk, atau siluet.',_MenuGroup.fun,Icons.person_search_rounded),
  _MenuFeature('quiz','Kuis Anime','Uji pengetahuan tentang anime, studio, karakter, dan pengisi suara.',_MenuGroup.fun,Icons.quiz_rounded),
  _MenuFeature('games','Mini Games','Tic-tac-toe, tebak kata, dan sambung kata untuk dimainkan lokal.',_MenuGroup.fun,Icons.sports_esports_rounded),
  _MenuFeature('music','Musik','Cari dan putar soundtrack anime melalui YouTube Music.',_MenuGroup.fun,Icons.music_note_rounded,url:'https://music.youtube.com/search?q=anime%20soundtrack',service:'YouTube Music'),
  _MenuFeature('explorer','Penjelajah Anime','Jelajahi anime berdasarkan studio, genre, tema, tahun, dan rekomendasi.',_MenuGroup.anime,Icons.travel_explore_rounded),
  _MenuFeature('characters','Database Karakter','Jelajahi karakter, pengisi suara, relasi, dan anime terkait.',_MenuGroup.anime,Icons.face_rounded),
  _MenuFeature('calendar','Kalender Anime','Jadwal episode terbaru, hitung mundur, dan pengingat tayang.',_MenuGroup.anime,Icons.calendar_month_rounded),
  _MenuFeature('stats','Statistik Anime','Grafik genre, studio favorit, waktu menonton, skor, dan riwayat tahunan.',_MenuGroup.anime,Icons.query_stats_rounded),
  _MenuFeature('collections','Koleksi','Kumpulan anime, karakter, studio, dan daftar favorit.',_MenuGroup.anime,Icons.collections_bookmark_rounded),
  _MenuFeature('compare','Perbandingan Anime','Bandingkan rating, popularitas, genre, durasi, dan statistik dua anime.',_MenuGroup.anime,Icons.compare_arrows_rounded),
  _MenuFeature('roulette','Anime Roulette','Pilih anime acak berdasarkan filter pilihan.',_MenuGroup.anime,Icons.casino_rounded),
  _MenuFeature('watch-together','Watch Together','Menonton bersama teman dengan sinkronisasi pemutaran.',_MenuGroup.anime,Icons.groups_rounded),
  _MenuFeature('timeline','Timeline Anime','Linimasa perkembangan anime dan franchise.',_MenuGroup.anime,Icons.timeline_rounded),
  _MenuFeature('map','Anime Map','Peta hubungan anime, karakter, prekuel, dan sekuel.',_MenuGroup.anime,Icons.hub_rounded),
  _MenuFeature('journal','Personal Journal','Catatan pribadi dan kesan setelah menonton anime.',_MenuGroup.anime,Icons.edit_note_rounded),
  _MenuFeature('ranking','Ranking Builder','Buat dan bagikan ranking anime versimu.',_MenuGroup.anime,Icons.leaderboard_rounded),
  _MenuFeature('challenge','Challenge','Tantangan menonton anime dengan target tertentu.',_MenuGroup.anime,Icons.flag_rounded),
  _MenuFeature('random-character','Random Character','Temukan karakter anime secara acak.',_MenuGroup.anime,Icons.shuffle_rounded),
  _MenuFeature('releases','Release Tracker','Pantau judul anime mendatang melalui katalog AniList.',_MenuGroup.anime,Icons.event_available_rounded,url:'https://anilist.co/search/anime?sort=START_DATE_DESC',service:'AniList'),
  _MenuFeature('match','Recommendation Match','Cari pengguna dengan selera anime yang mirip.',_MenuGroup.anime,Icons.favorite_rounded),
  _MenuFeature('news','Anime News','Baca berita anime dari Anime News Network.',_MenuGroup.anime,Icons.newspaper_rounded,url:'https://www.animenewsnetwork.com/',service:'Anime News Network'),
  _MenuFeature('screenshots','Screenshot Gallery','Jelajahi dan simpan screenshot anime favorit.',_MenuGroup.anime,Icons.photo_library_rounded),
];
const _labels = {_MenuGroup.community:'Komunitas',_MenuGroup.fun:'Hiburan',_MenuGroup.anime:'Anime'};

class MenuHubScreen extends StatefulWidget {
  const MenuHubScreen({super.key});
  @override State<MenuHubScreen> createState()=>_MenuHubScreenState();
}
class _MenuHubScreenState extends State<MenuHubScreen> {
  static const _boxName='menu_hub_prefs',_enabledKey='enabled_features';
  Box? _box;
  Set<String> _enabled=_features.map((f)=>f.id).toSet();
  _MenuGroup? _group;
  String _query='';
  bool _loading=true,_editing=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final box=Hive.isBoxOpen(_boxName)?Hive.box(_boxName):await openBoxSafely(_boxName);
      final saved=box.get(_enabledKey);
      if(saved is List){final valid=saved.whereType<String>().toSet();_enabled=_features.where((f)=>valid.contains(f.id)).map((f)=>f.id).toSet();}
      _box=box;
    } catch (_) {}
    if(mounted)setState(()=>_loading=false);
  }
  Future<void> _toggle(_MenuFeature f) async {
    setState(()=>_enabled.contains(f.id)?_enabled.remove(f.id):_enabled.add(f.id));
    await _box?.put(_enabledKey,_enabled.toList());
  }
  List<_MenuFeature> get _visible=>_features.where((f)=>(_group==null||f.group==_group)&&(_query.isEmpty||f.title.toLowerCase().contains(_query.toLowerCase())||f.description.toLowerCase().contains(_query.toLowerCase()))&&(_editing||_enabled.contains(f.id))).toList();
  @override Widget build(BuildContext context){
    final rows=_visible;
    return Scaffold(backgroundColor:AppColors.bg,body:SafeArea(child:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(18,18,18,12),child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Menu',style:AppText.headline.copyWith(color:AppColors.textPrimary,fontSize:25,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),Text('Community & Entertainment Hub',style:AppText.caption.copyWith(color:AppColors.textSecondary)),
        ])),
        IconButton(tooltip:_editing?'Selesai mengatur':'Atur fitur',onPressed:()=>setState(()=>_editing=!_editing),icon:Icon(_editing?Icons.check_rounded:Icons.tune_rounded,color:AppColors.accent)),
      ]))),
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:TextField(
        onChanged:(v)=>setState(()=>_query=v.trim()),style:AppText.body.copyWith(color:AppColors.textPrimary),
        decoration:InputDecoration(hintText:'Cari fitur...',prefixIcon:const Icon(Icons.search_rounded),filled:true,fillColor:AppColors.surface2,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(vertical:12)),
      ))),
      SliverToBoxAdapter(child:SizedBox(height:46,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14),children:[
        _chip('Semua',_group==null,()=>setState(()=>_group=null)),
        for(final g in _MenuGroup.values)_chip(_labels[g]!,_group==g,()=>setState(()=>_group=g)),
      ]))),
      if(_editing) SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(18,8,18,4),child:Text('Pilih fitur yang ingin ditampilkan. Perubahan tersimpan otomatis.',style:AppText.caption.copyWith(color:AppColors.textSecondary)))),
      if(_loading) const SliverFillRemaining(child:Center(child:CircularProgressIndicator()))
      else if(rows.isEmpty) SliverFillRemaining(child:Center(child:Text('Tidak ada fitur yang cocok.',style:AppText.body.copyWith(color:AppColors.textSecondary))))
      else SliverPadding(padding:const EdgeInsets.fromLTRB(14,12,14,32),sliver:SliverGrid(
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:.94),
        delegate:SliverChildBuilderDelegate((context,i){final f=rows[i];final enabled=_enabled.contains(f.id);return _FeatureTile(feature:f,enabled:enabled,editing:_editing,onTap:(){
          if(_editing){_toggle(f);}else{_openFeature(f);}
        });},childCount:rows.length),
      )),
    ])));
  }
  void _openFeature(_MenuFeature feature) {
    final Widget? page = switch (feature.id) {
      'notifications' => const NotificationsScreen(),
      'calendar' => const ScheduleScreen(),
      'explorer' => const ExploreScreen(),
      'watch-together' => const WatchPartyLobbyScreen(),
      'forum' => const MenuForumScreen(),
      'feed' || 'users' => MenuSocialScreen(featureId: feature.id),
      'characters' || 'stats' || 'compare' => MenuCatalogToolsScreen(featureId: feature.id),
      'ranking' || 'collections' => MenuPersonalListScreen(featureId: feature.id),
      'timeline' || 'map' => MenuRelationsScreen(timeline: feature.id == 'timeline'),
      'polls' => const MenuPollsScreen(),
      'messages' => const MenuMessagesScreen(),
      'match' => const MenuRecommendationMatchScreen(),
      'journal' || 'challenge' || 'games' || 'roulette' || 'random-character' || 'guess' || 'quiz' || 'screenshots' => MenuToolsScreen(featureId: feature.id),
      _ => null,
    };
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => page ?? _MenuFeatureScreen(feature: feature),
    ));
  }
  Widget _chip(String label,bool selected,VoidCallback onTap)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(label),selected:selected,onSelected:(_)=>onTap(),selectedColor:AppColors.accent.withValues(alpha:.18),labelStyle:AppText.caption.copyWith(color:selected?AppColors.accent:AppColors.textSecondary,fontWeight:selected?FontWeight.w700:FontWeight.w500),side:BorderSide(color:selected?AppColors.accent.withValues(alpha:.5):AppColors.hairline),backgroundColor:AppColors.surface));
}
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature,required this.enabled,required this.editing,required this.onTap});
  final _MenuFeature feature;final bool enabled,editing;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Material(color:AppColors.surface,borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:onTap,child:Stack(children:[
    Padding(padding:const EdgeInsets.all(10),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(width:45,height:45,decoration:BoxDecoration(color:AppColors.accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(feature.icon,color:AppColors.accent,size:24)),
      const SizedBox(height:9),Text(feature.title,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:AppText.caption.copyWith(color:AppColors.textPrimary,fontWeight:FontWeight.w700,fontSize:11.5)),
    ])),
    if(editing)Positioned(right:6,top:6,child:Icon(enabled?Icons.check_circle_rounded:Icons.add_circle_outline_rounded,size:18,color:enabled?AppColors.accent:AppColors.textTertiary)),
  ])));
}
class _MenuFeatureScreen extends StatelessWidget {
  const _MenuFeatureScreen({required this.feature});
  final _MenuFeature feature;
  Future<void> _open(BuildContext context) async {
    final url=feature.url;if(url==null)return;
    final ok=await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
    if(!ok&&context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tidak bisa membuka layanan ini.')));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(backgroundColor:AppColors.bg,foregroundColor:AppColors.textPrimary,title:Text(feature.title,style:AppText.title.copyWith(color:AppColors.textPrimary))),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      Center(child:Container(width:84,height:84,decoration:BoxDecoration(color:AppColors.accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(24)),child:Icon(feature.icon,color:AppColors.accent,size:42))),
      const SizedBox(height:20),
      Text(feature.title,textAlign:TextAlign.center,style:AppText.headline.copyWith(color:AppColors.textPrimary,fontSize:23,fontWeight:FontWeight.w800)),
      const SizedBox(height:10),Text(feature.description,textAlign:TextAlign.center,style:AppText.body.copyWith(color:AppColors.textSecondary,height:1.5)),
      const SizedBox(height:22),
      if(feature.url!=null)FilledButton.icon(onPressed:()=>_open(context),icon:const Icon(Icons.open_in_new_rounded),label:Text('Buka ${feature.service??'layanan'}'),style:FilledButton.styleFrom(backgroundColor:AppColors.accent,foregroundColor:Colors.white,minimumSize:const Size.fromHeight(48))),
      const SizedBox(height:18),
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(14)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(Icons.info_outline_rounded,color:AppColors.accent,size:20),const SizedBox(width:10),
        Expanded(child:Text(feature.url!=null?'Akses layanan ${feature.service} saat ini dibuka melalui aplikasi atau browser. Integrasi langsung di dalam AnimeW masih perlu dikembangkan.':'Halaman fitur sudah disiapkan. Integrasi data dan interaksi khusus fitur ini perlu dikembangkan pada tahap berikutnya.',style:AppText.caption.copyWith(color:AppColors.textSecondary,height:1.45))),
      ])),
    ]),
  );
}
