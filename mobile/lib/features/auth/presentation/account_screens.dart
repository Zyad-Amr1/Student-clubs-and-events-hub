import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/app/design.dart';
import 'package:campusconnect/app/routes.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:campusconnect/shared/widgets/pick_image.dart';
import 'package:material_ui/material_ui.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen(this.profile, {super.key});
  final StudentProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.profile.fullName);
  late String? _faculty = widget.profile.faculty;
  late String? _department = widget.profile.department;
  late int? _year = widget.profile.academicYear;
  late Future<JsonObject> _catalog;
  String? _image;
  String? _error;
  bool _changedImage = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadCatalog();
    }
  }

  bool _initialized = false;

  void _loadCatalog() {
    final session = StudentSessionScope.of(context);
    _catalog = session.authenticated(session.api.academicCatalog);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final image = await pickImage();
      if (mounted && image != null) {
        setState(() {
          _image = image;
          _changedImage = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Choose a JPEG or PNG up to 512 KiB.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StudentSessionScope.of(context).updateProfile({
        'full_name': _name.text.trim(),
        'faculty': _faculty,
        'department': _department,
        'academic_year': _year,
        if (_changedImage) 'picture_base64': _image,
      });
      if (mounted) Navigator.of(context).pop();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dropdown<T>(
    String label,
    T? value,
    Iterable<T> values,
    ValueChanged<T?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: !_busy),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          isDense: true,
          value: values.contains(value) ? value : null,
          hint: const Text('Not specified'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Not specified')),
            for (final item in values)
              DropdownMenuItem(value: item, child: Text('$item')),
          ],
          onChanged: _busy ? null : change,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: FutureBuilder<JsonObject>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: CampusFeedback(
              '${snapshot.error}',
              icon: Icons.error_outline,
              retry: () => setState(_loadCatalog),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final faculties = (snapshot.data!['faculties'] as Map)
            .cast<String, List>();
        final departments =
            faculties[_faculty]?.cast<String>() ?? const <String>[];
        final years = (snapshot.data!['years'] as List).cast<int>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: CampusColors.lavender,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    UploadedImage(
                      _changedImage
                          ? (_image == null
                                ? null
                                : 'data:image/jpeg;base64,$_image')
                          : widget.profile.picture,
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _pick,
                          child: Text(
                            _image == null
                                ? 'Choose picture'
                                : 'Picture selected',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _changedImage = true;
                                  _image = null;
                                }),
                          child: const Text('Remove picture'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const CampusSectionHeader(title: 'Personal information'),
            TextField(
              controller: _name,
              maxLength: 120,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            Text('Email · ${widget.profile.email}'),
            Text('University ID · ${widget.profile.universityId}'),
            const SizedBox(height: 12),
            const CampusSectionHeader(title: 'Academic information'),
            _dropdown(
              'Faculty',
              _faculty,
              faculties.keys,
              (value) => setState(() {
                _faculty = value;
                if (!(faculties[value]?.contains(_department) ?? false)) {
                  _department = null;
                }
              }),
            ),
            _dropdown(
              'Department',
              _department,
              departments,
              (value) => setState(() => _department = value),
            ),
            _dropdown(
              'Academic year',
              _year,
              years,
              (value) => setState(() => _year = value),
            ),
            if (_error != null)
              CampusFeedback(_error!, icon: Icons.error_outline),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save profile'),
            ),
          ],
        );
      },
    ),
  );
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_current.text.isEmpty ||
        _new.text.length < 8 ||
        _new.text != _confirm.text) {
      setState(
        () => _message = 'Enter your current password and matching new passwords of at least 8 characters.',
      );
      return;
    }
    final session = StudentSessionScope.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await session.authenticated(
        (token) => session.api.changePassword(token, {
          'current_password': _current.text,
          'new_password': _new.text,
          'confirm_password': _confirm.text,
        }),
      );
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _confirm.clear();
      _message = 'Password changed.';
    } on ApiFailure catch (error) {
      _message = error.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    String? warning;
    try {
      await StudentSessionScope.of(context).logout();
    } on ApiFailure catch (error) {
      warning = error.message;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = StudentSessionScope.of(context).signedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!signedIn)
            const Text('Sign in again to change your password.')
          else ...[
            const CampusSectionHeader(title: 'Password'),
            for (final entry in {
              'Current password': _current,
              'New password': _new,
              'Confirm new password': _confirm,
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: entry.value,
                  enabled: !_busy,
                  obscureText: true,
                  maxLength: 128,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ),
            if (_message != null) CampusFeedback(_message!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _change,
              child: const Text('Change password'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _logout,
              child: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}
