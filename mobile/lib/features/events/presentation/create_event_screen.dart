import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

/// Small club-scoped MVP editor; only the backend can create/submit events.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({required this.club, super.key});

  final ManagedClub club;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _capacity = TextEditingController(text: '40');
  DateTime? _startsAt;
  ManagedEvent? _draft;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _venue.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _chooseStart() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (!mounted || time == null) return;
    setState(() {
      _startsAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _error = null;
    });
  }

  String? _required(String? text) =>
      text == null || text.trim().isEmpty ? 'Required field' : null;

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final capacity = int.tryParse(_capacity.text.trim());
    if (capacity == null || capacity < 1 || capacity > 100000) {
      setState(() => _error = 'Capacity must be between 1 and 100000.');
      return;
    }
    if (_startsAt == null || !_startsAt!.isAfter(DateTime.now())) {
      setState(() => _error = 'Select a future date and time.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = StudentSessionScope.of(context);
      final created = await session.authenticated((token) =>
          session.api.createDraftEvent(
            token: token,
            clubId: widget.club.id,
            title: _title.text,
            description: _description.text,
            venue: _venue.text,
            startsAt: _startsAt!,
            seatCapacity: capacity,
          ));
      if (mounted) setState(() => _draft = created);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create draft event.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null || draft.approvalStatus != 'draft') return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = StudentSessionScope.of(context);
      final submitted = await session.authenticated(
        (token) => session.api.submitDraftEvent(token, widget.club.id, draft.id),
      );
      if (mounted) setState(() => _draft = submitted);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit draft event.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _draft;
    return Scaffold(
      appBar: AppBar(title: Text('Manage events · ${widget.club.name}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (current == null) ...[
              Text('Create a draft for ${widget.club.name}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Drafts are unpublished until Student Affairs approval.'),
              const SizedBox(height: 18),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('draft-title'),
                      controller: _title,
                      validator: _required,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Event title'),
                    ),
                    TextFormField(
                      key: const ValueKey('draft-description'),
                      controller: _description,
                      validator: _required,
                      maxLength: 10000,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    TextFormField(
                      key: const ValueKey('draft-venue'),
                      controller: _venue,
                      validator: _required,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'Venue'),
                    ),
                    TextFormField(
                      key: const ValueKey('draft-capacity'),
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seat capacity'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('pick-start-date'),
                onPressed: _busy ? null : _chooseStart,
                icon: const Icon(Icons.event_outlined),
                label: Text(_startsAt == null
                    ? 'Select start date and time'
                    : 'Starts: ${_startsAt!.toLocal()}'),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('create-draft'),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Create draft'),
              ),
            ] else ...[
              Text(current.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Status: ${current.approvalStatus}',
                  key: const ValueKey('draft-status')),
              Text('Published: ${current.isPublished ? 'Yes' : 'No'}'),
              Text('Venue: ${current.venue}'),
              Text('Starts: ${current.startsAt.toLocal()}'),
              const SizedBox(height: 20),
              if (current.approvalStatus == 'draft')
                FilledButton.icon(
                  key: const ValueKey('submit-draft'),
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit for Student Affairs review'),
                ),
              if (current.approvalStatus == 'pending')
                const Text('Submitted. Awaiting Student Affairs approval.'),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('new-draft'),
                onPressed: _busy ? null : () => setState(() {
                  _draft = null;
                  _startsAt = null;
                  _formKey.currentState?.reset();
                }),
                child: const Text('Create another draft'),
              ),
            ],
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('event-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
