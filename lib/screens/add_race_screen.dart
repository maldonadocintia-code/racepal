import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../theme.dart';

class AddRaceScreen extends StatefulWidget {
  /// When opened from the Plan tab's "add manually" fallback, the date the
  /// user tapped is pre-filled into the manual race form.
  final DateTime? initialDate;
  const AddRaceScreen({super.key, this.initialDate});

  @override
  State<AddRaceScreen> createState() => _AddRaceScreenState();
}

class _AddRaceScreenState extends State<AddRaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add new event'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Race'),
            Tab(text: 'Parkrun'),
          ],
          indicatorColor: c.primary,
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ManualRaceForm(initialDate: widget.initialDate),
          const _ParkrunSelector(),
        ],
      ),
    );
  }
}

class _ManualRaceForm extends StatefulWidget {
  final DateTime? initialDate;
  const _ManualRaceForm({this.initialDate});

  @override
  State<_ManualRaceForm> createState() => _ManualRaceFormState();
}

class _ManualRaceFormState extends State<_ManualRaceForm> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = '10K';
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Race name *',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location *',
              hintText: 'Town, County',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          // Type selector
          Text('Race type',
              style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.raceTypes
                .where((t) => t != 'parkrun')
                .map((t) => GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _type == t ? c.filterActive : c.filterInactive,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                              color: _type == t
                                  ? Colors.transparent
                                  : c.filterBorder),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: _type == t
                                ? c.filterActiveText
                                : c.filterInactiveText,
                            fontSize: AppType.sm,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: c.bgInput,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: c.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _date == null
                        ? 'Select date *'
                        : DateFormat('EEE, d MMMM yyyy').format(_date!),
                    style: TextStyle(
                      color: _date == null ? c.textSecondary : c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Website (optional)',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add event'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final race = Race(
      id: '',
      name: _nameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      type: _type,
      category: RaceCategory.race,
      date: _date!,
      website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      createdBy: provider.currentUser!.uid,
    );
    await provider.addRace(race);
    if (mounted) Navigator.pop(context);
  }
}

class _ParkrunSelector extends StatefulWidget {
  const _ParkrunSelector();

  @override
  State<_ParkrunSelector> createState() => _ParkrunSelectorState();
}

class _ParkrunSelectorState extends State<_ParkrunSelector> {
  List<Map<String, dynamic>> _parkruns = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _selected;
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final str = await rootBundle.loadString('assets/parkruns_uk.json');
    final bundled = (jsonDecode(str) as List).cast<Map<String, dynamic>>();
    // User-created parkruns (from Firestore) sit above the bundled catalog so a
    // venue you just added is right at the top of the list.
    List<Map<String, dynamic>> venues = const [];
    try {
      venues = await provider.raceService.parkrunVenues();
    } catch (_) {
      // Offline / permission hiccup — fall back to the bundled catalog only.
    }
    if (!mounted) return;
    final all = [...venues, ...bundled];
    setState(() {
      _parkruns = all;
      _filtered = all;
    });
    _filter(); // re-apply any active search query against the merged list
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _parkruns
          : _parkruns
              .where((p) =>
                  p['name'].toString().toLowerCase().contains(q) ||
                  p['location'].toString().toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search parkruns...',
              prefixIcon: Icon(Icons.search, color: c.searchIcon),
            ),
          ),
        ),
        if (_selected != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.primaryMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: AppPalette.goGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selected!['name']} parkrun',
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selected = null),
                      child: Icon(Icons.close, size: 18, color: c.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_selected!['location'].toString(),
                    style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.bgInput,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: c.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _date == null
                              ? 'Select Saturday *'
                              : DateFormat('EEE, d MMMM yyyy').format(_date!),
                          style: TextStyle(
                            color: _date == null ? c.textSecondary : c.textPrimary,
                            fontSize: AppType.sm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add to calendar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final p = _filtered[i];
              return ListTile(
                leading: Icon(Icons.bolt, color: AppPalette.goGreen, size: 20),
                title: Text('${p['name']} parkrun',
                    style: TextStyle(color: c.textPrimary)),
                subtitle: Text(p['location'].toString(),
                    style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
                onTap: () => setState(() => _selected = p),
                selected: _selected?['id'] == p['id'],
                selectedTileColor: c.primaryMuted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextButton.icon(
              onPressed: _addManually,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text("Can't find your parkrun? Add it manually"),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the manual parkrun form. When it returns, reload so a just-created
  /// venue shows up in the list.
  Future<void> _addManually() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _ManualParkrunScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Find next Saturday
    final nextSaturday = now.add(Duration(days: (6 - now.weekday % 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: nextSaturday,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_selected == null || _date == null) return;
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final race = Race.fromParkrunJson(_selected!, _date!);
    await provider.addRace(race);
    if (mounted) Navigator.pop(context);
  }
}

/// Form for adding a parkrun that isn't in the bundled catalog. It creates a
/// *venue* (no date) so it becomes selectable by every user from the parkrun
/// list; choosing which Saturday to run happens later via the normal picker.
class _ManualParkrunScreen extends StatelessWidget {
  const _ManualParkrunScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a parkrun')),
      body: const _ManualParkrunForm(),
    );
  }
}

class _ManualParkrunForm extends StatefulWidget {
  const _ManualParkrunForm();

  @override
  State<_ManualParkrunForm> createState() => _ManualParkrunFormState();
}

class _ManualParkrunFormState extends State<_ManualParkrunForm> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.primaryMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: c.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Adds a new parkrun everyone can find in the list. '
                    'Pick which Saturday to run it afterwards.',
                    style:
                        TextStyle(color: c.textSecondary, fontSize: AppType.sm),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Parkrun name *',
              hintText: 'e.g. Heaton',
              helperText: "We'll add “parkrun” for you",
              prefixIcon: Icon(Icons.directions_run),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Location *',
              hintText: 'Town, County',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _websiteCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Website (optional)',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create parkrun'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    if (name.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a name and location')),
      );
      return;
    }
    // Store the bare name (no "parkrun" suffix) so it renders consistently with
    // the bundled catalog, which appends "parkrun" in the UI.
    final bare =
        name.replaceAll(RegExp(r'\s*parkrun\s*$', caseSensitive: false), '').trim();
    if (bare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the parkrun name')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final website = _websiteCtrl.text.trim();
    try {
      await provider.raceService.addParkrunVenue(
        name: bare,
        location: location,
        createdBy: provider.currentUser!.uid,
        website: website.isNotEmpty ? website : null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save — please try again")),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$bare parkrun added — now pick a Saturday')),
    );
  }
}
