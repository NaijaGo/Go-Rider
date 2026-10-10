import 'package:flutter/material.dart';
import '../../../core/auth/google_auth_service.dart';
import '../../../core/push/onesignal_service.dart';
import '../../orders/service/rider_api.dart';

class GoogleLoginView extends StatefulWidget {
  final Future<String?> Function()? authenticate;
  final Future<Map<String, dynamic>> Function(String, String?)? request;
  const GoogleLoginView({super.key, this.authenticate, this.request});
  @override
  State<GoogleLoginView> createState() => _GoogleLoginViewState();
}

class _GoogleLoginViewState extends State<GoogleLoginView> {
  final _password = TextEditingController();
  String? _token;
  String? _error;
  bool _busy = false;
  bool _linkRequired = false;
  @override
  void initState() {
    super.initState();
    _submit();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_linkRequired && _password.text.isEmpty) {
      setState(() => _error = 'Enter your existing NaijaGo rider password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _token ??= await (widget.authenticate ?? GoogleAuthService.idToken)();
      if (!mounted) return;
      if (_token == null) {
        Navigator.of(context).pop();
        return;
      }
      final pushId = widget.request == null
          ? await OneSignalService.pushSubscriptionId()
          : null;
      final data =
          await (widget.request?.call(
                _token!,
                _linkRequired ? _password.text : null,
              ) ??
              RiderApi.googleLogin(
                _token!,
                linkPassword: _linkRequired ? _password.text : null,
                oneSignalPlayerId: pushId,
              ));
      if (!mounted) return;
      if (data['httpStatus'] == 200) {
        if (data['token'] is! String ||
            (data['token'] as String).isEmpty ||
            data['_id'] == null) {
          throw const FormatException();
        }
        Navigator.of(context).pop(data);
      } else if (data['httpStatus'] == 202 &&
          data['code'] == 'GOOGLE_RIDER_ONBOARDING_REQUIRED') {
        if (data['profile'] is! Map) {
          throw const FormatException();
        }
        Navigator.of(context).pop({...data, 'googleIdToken': _token});
      } else if (data['code'] == 'GOOGLE_LINK_REQUIRED') {
        setState(() => _linkRequired = true);
      } else {
        if (data['code'] == 'GOOGLE_TOKEN_INVALID') _token = null;
        setState(
          () => _error =
              data['message']?.toString() ??
              'Unable to sign in right now. Please try again.',
        );
      }
    } on GoogleAuthUnavailable catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to connect right now. Please try again or use email and password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Continue with Google')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_linkRequired) ...[
              const Text(
                'Verify your existing NaijaGo rider password once to link this Google account.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Existing password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Forgot your password? Return to login and use Forgot password.',
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: _submit,
                child: Text(_linkRequired ? 'Link and continue' : 'Try again'),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    ),
  );
}
