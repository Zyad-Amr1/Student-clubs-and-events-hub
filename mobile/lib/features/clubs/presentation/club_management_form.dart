import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/shared/widgets/pick_image.dart';
import 'package:material_ui/material_ui.dart';

class ClubManagementForm extends StatefulWidget {
  const ClubManagementForm({this.request, this.club, super.key});
  final ClubCreationRequest? request;
  final CampusClub? club;

  @override
  State<ClubManagementForm> createState() => _ClubManagementFormState();
}

class _ClubManagementFormState extends State<ClubManagementForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.club?.name ?? widget.request?.name,
  );
  late final _description = TextEditingController(
    text: widget.club?.description ?? widget.request?.description,
  );
  late final _category = TextEditingController(
    text: widget.club?.category ?? widget.request?.category,
  );
  String? _image;
  bool _logoChanged = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    setState(() => _busy = true);
    try {
      final image = await pickImage();
      if (mounted && image != null) {
        _image = image;
        _logoChanged = true;
        _error = null;
      }
    } catch (_) {
      _error = 'Choose a JPEG or PNG up to 512 KiB.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final session = StudentSessionScope.of(context);
    final club = widget.club;
    final data = <String, dynamic>{
      if (club == null) 'name': _name.text.trim(),
      'description': _description.text.trim(),
      'category': _category.text.trim(),
      if (_logoChanged) 'logo_base64': _image,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (club != null) {
        await session.authenticated(
          (token) => session.api.updateManagedClub(token, club.id, data),
        );
      } else {
        await session.authenticated(
          (token) =>
              session.api.saveClubRequest(token, data, id: widget.request?.id),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editingClub = widget.club != null;
    final title = editingClub
        ? 'Edit Club Profile'
        : widget.request != null
        ? 'Edit Club Request'
        : 'Request a New Club';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (editingClub)
                Text('Club name · ${widget.club!.name}')
              else
                _field(_name, 'Club name', 120),
              _field(_description, 'Description', 3000, lines: 5),
              _field(_category, 'Category', 80),
              Center(
                child: UploadedImage(
                  _logoChanged
                      ? null
                      : widget.club?.logoUrl ?? widget.request?.logoUrl,
                ),
              ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: _busy ? null : _selectImage,
                    child: Text(
                      _image == null ? 'Choose logo' : 'Logo selected',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _logoChanged = true;
                            _image = null;
                          }),
                    child: const Text('Remove logo'),
                  ),
                ],
              ),
              if (_error != null) Text(_error!),
              if (_busy) const LinearProgressIndicator(),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  editingClub || widget.request != null
                      ? 'Save changes'
                      : 'Submit request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int limit, {
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    enabled: !_busy,
    maxLength: limit,
    maxLines: lines,
    decoration: InputDecoration(labelText: label),
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Enter ${label.toLowerCase()}.'
        : null,
  );
}

class ManagedClubProfileScreen extends StatefulWidget {
  const ManagedClubProfileScreen(this.clubId, {super.key});
  final String clubId;

  @override
  State<ManagedClubProfileScreen> createState() =>
      _ManagedClubProfileScreenState();
}

class _ManagedClubProfileScreenState extends State<ManagedClubProfileScreen> {
  Future<CampusClub>? _club;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _club ??= _fetch();
  }

  Future<CampusClub> _fetch() {
    final session = StudentSessionScope.of(context);
    return session.authenticated(
      (token) => session.api.managedClubProfile(token, widget.clubId),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CampusClub>(
    future: _club,
    builder: (context, snapshot) {
      if (snapshot.hasData) return ClubManagementForm(club: snapshot.data);
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Club Profile')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}'),
                    TextButton(
                      onPressed: () => setState(() => _club = _fetch()),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
