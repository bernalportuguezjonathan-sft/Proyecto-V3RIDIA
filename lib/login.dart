import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_google.dart';
import 'services/repositorio_u.dart';
import 'models/user.dart';
import 'register.dart';
import 'theme/veridia_theme.dart';
import 'widgets/animated_visibility.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/veridia_logo.dart';
import 'widgets/veridia_montanas.dart';
import 'widgets/veridia_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

const int _maxIntentosLogin = 3;
const int _bloqueoSegundos = 60;

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminCodeController = TextEditingController();
  String _selectedRole = 'Explorador';

  Timer? _lockTimer;
  int _segundosRestantesBloqueo = 0;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
        ),
      );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
  );

  void _mostrarAlerta(String mensaje) {
    mostrarMensajeVeridia(context, mensaje, esError: true);
  }

  String _claveIntentos(String email) => 'login_intentos_$email';
  String _claveBloqueo(String email) => 'login_bloqueo_hasta_$email';

  Future<int> _obtenerSegundosBloqueoRestantes(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final bloqueadoHastaMs = prefs.getInt(_claveBloqueo(email));
    if (bloqueadoHastaMs == null) return 0;
    final restante = DateTime.fromMillisecondsSinceEpoch(
      bloqueadoHastaMs,
    ).difference(DateTime.now()).inSeconds;
    return restante > 0 ? restante : 0;
  }

  Future<void> _registrarIntentoFallido(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final intentos = (prefs.getInt(_claveIntentos(email)) ?? 0) + 1;
    if (intentos >= _maxIntentosLogin) {
      final hasta = DateTime.now().add(
        const Duration(seconds: _bloqueoSegundos),
      );
      await prefs.setInt(_claveBloqueo(email), hasta.millisecondsSinceEpoch);
      await prefs.setInt(_claveIntentos(email), 0);
      _iniciarCuentaRegresiva(_bloqueoSegundos);
    } else {
      await prefs.setInt(_claveIntentos(email), intentos);
    }
  }

  Future<void> _resetearIntentos(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveIntentos(email));
    await prefs.remove(_claveBloqueo(email));
  }

  void _iniciarCuentaRegresiva(int segundos) {
    _lockTimer?.cancel();
    setState(() => _segundosRestantesBloqueo = segundos);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantesBloqueo <= 1) {
        timer.cancel();
        setState(() => _segundosRestantesBloqueo = 0);
      } else {
        setState(() => _segundosRestantesBloqueo--);
      }
    });
  }

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Correo electrónico');
      return;
    }
    if (password.isEmpty) {
      _mostrarAlerta('Por favor llena el campo de Contraseña');
      return;
    }

    final segundosBloqueo = await _obtenerSegundosBloqueoRestantes(email);
    if (segundosBloqueo > 0) {
      _iniciarCuentaRegresiva(segundosBloqueo);
      _mostrarAlerta(
        'Demasiados intentos fallidos. Intenta de nuevo en '
        '$segundosBloqueo segundos.',
      );
      return;
    }
    if (!mounted) return;

    // El rol real vive en Firestore y ya no se puede autoasignar (ver
    // firestore.rules); _handleAuthenticatedUser rechaza el login si el rol
    // elegido aquí no coincide con el guardado.

    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: VeridiaLoader()),
      ),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _resetearIntentos(email);

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null &&
          !authUser.emailVerified &&
          authUser.providerData.any((p) => p.providerId == 'password')) {
        if (mounted) Navigator.pop(context);
        await _mostrarDialogoCorreoNoVerificado(authUser);
        return;
      }

      try {
        await UserRepository.instance.initializeUser();
      } catch (e, st) {
        if (mounted) Navigator.pop(context);
        debugPrint('Error initializing user: $e\n$st');
        _mostrarAlerta('Error al inicializar usuario: ${e.toString()}');
        return;
      }

      if (mounted) Navigator.pop(context);

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _mostrarAlerta('No se pudo obtener el usuario autenticado.');
        return;
      }

      await _handleAuthenticatedUser(firebaseUser);
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential') {
        await _registrarIntentoFallido(email);
        _mostrarAlerta('Correo o contraseña incorrectos.');
      } else if (e.code == 'invalid-email') {
        _mostrarAlerta('El formato del correo es incorrecto.');
      } else if (e.code == 'user-disabled') {
        _mostrarAlerta('La cuenta ha sido deshabilitada.');
      } else if (e.code == 'too-many-requests') {
        _mostrarAlerta(
          'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
        );
      } else {
        _mostrarAlerta('Error al iniciar sesión. Verifica tus datos.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarAlerta('Ocurrió un error inesperado de conexión.');
    }
  }

  Future<void> _mostrarDialogoCorreoNoVerificado(User authUser) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_unread_outlined,
          color: VeridiaColors.secondary,
          size: 28,
        ),
        title: const Text('Verifica tu correo'),
        content: const Text(
          'Debes confirmar tu correo electrónico antes de iniciar sesión. '
          'Revisa tu bandeja de entrada o solicita un nuevo enlace.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await authUser.sendEmailVerification();
                if (dialogContext.mounted) {
                  mostrarMensajeVeridia(
                    dialogContext,
                    'Correo de verificación reenviado.',
                  );
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  mostrarMensajeVeridia(
                    dialogContext,
                    'No se pudo reenviar el correo. Intenta más tarde.',
                    esError: true,
                  );
                }
              }
            },
            child: const Text('Reenviar correo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _olvideContrasena() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Tu correo electrónico'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        mostrarMensajeVeridia(
          context,
          'Si el correo está registrado, te enviamos un enlace para '
          'restablecer tu contraseña.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        _mostrarAlerta('El formato del correo es incorrecto.');
      } else {
        // No confirmamos si el correo existe o no, para no filtrar esa
        // información a un posible atacante.
        if (mounted) {
          mostrarMensajeVeridia(
            context,
            'Si el correo está registrado, te enviamos un enlace para '
            'restablecer tu contraseña.',
          );
        }
      }
    } catch (_) {
      _mostrarAlerta('Ocurrió un error inesperado de conexión.');
    }
  }

  Future<void> _handleAuthenticatedUser(User firebaseUser) async {
    UserProfile? userProfile = UserRepository.instance.currentUser.value;
    final dbProfile = await UserRepository.instance.getUserProfileById(
      firebaseUser.uid,
    );
    if (dbProfile != null) {
      userProfile = dbProfile;
      UserRepository.instance.currentUser.value = userProfile;
    }

    if (userProfile == null) {
      // Sin documento en Firestore no hay forma de confiar en ningún rol
      // elegido en pantalla; se crea siempre como Explorador.
      userProfile = UserProfile(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName:
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'Usuario',
        photoURL: firebaseUser.photoURL,
        tokens: 0,
        role: 'Explorador',
        createdDate: DateTime.now(),
        isBanned: false,
        banExpires: null,
        banReason: null,
      );
      UserRepository.instance.currentUser.value = userProfile;
    }

    if (userProfile.isBanned) {
      final now = DateTime.now();
      final vencida =
          userProfile.banExpires != null &&
          userProfile.banExpires!.isBefore(now);
      // Solo se deja entrar si la suspensión venció Y el servidor aceptó
      // levantarla. Si la rechaza, el usuario sigue suspendido de verdad.
      final levantada =
          vencida &&
          await UserRepository.instance.intentarLevantarSuspension(
            userProfile.userId,
          );

      if (levantada) {
        userProfile = userProfile.copyWith(
          isBanned: false,
          banExpires: null,
          banReason: null,
        );
        UserRepository.instance.currentUser.value = userProfile;
      } else {
        final banLabel = userProfile.banExpires == null
            ? 'Suspensión Permanente'
            : 'Suspendido hasta ${formatoFecha(userProfile.banExpires!)}';
        final banReason = userProfile.banReason ?? 'Motivo no disponible';
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.gpp_bad_outlined,
              color: VeridiaColors.error,
              size: 28,
            ),
            title: const Text('Cuenta suspendida'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VeridiaTag(
                  label: banLabel,
                  icon: Icons.schedule,
                  color: VeridiaColors.error,
                ),
                const SizedBox(height: 12),
                Text(banReason),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        if (mounted) {
          await UserRepository.instance.signOut();
        }
        return;
      }
    }

    if (userProfile.role != _selectedRole) {
      _mostrarAlerta(
        'El usuario ingresado no tiene el rol seleccionado. '
        'Selecciona ${userProfile.role} o corrige el rol.',
      );
      return;
    }

    if (!mounted) return;
    // Vaciar la pila, NO empujar la pantalla de destino.
    //
    // [RaizVeridia] es la primera ruta y ya escucha `authStateChanges`: en
    // cuanto hay sesión dibuja ella sola el panel de administración o el
    // inicio del explorador. Empujar aquí otra encima dejaba DOS iguales
    // apiladas —la de arriba con flecha de retroceso, la de abajo sin ella—,
    // así que tocar la flecha "volvía" a la misma pantalla y la flecha
    // desaparecía, sin forma evidente de salir.
    //
    // Es el mismo criterio que ya usan `VeridiaNav.ir` para Inicio y
    // `VeridiaNav.cerrarSesion`: la raíz decide qué se ve, y navegar es
    // dejarla a ella sola.
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// Avisa de que la cuenta de Google elegida no está registrada en Veridia.
  ///
  /// Devuelve true si la persona quiere crear la cuenta con ese correo, false
  /// si lo que pasó es que se equivocó de cuenta.
  ///
  /// No se cancela tocando fuera: equivocarse de cuenta es justo el momento en
  /// el que hay que leer, y un diálogo que se cierra solo devolvería al mismo
  /// silencio que causaba el problema.
  Future<bool> _preguntarPorCuentaNoRegistrada(String correo) async {
    final respuesta = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VeridiaColors.surfaceContainerHigh,
        title: const Text('Esta cuenta no está registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              correo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: VeridiaColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No tiene ninguna cuenta de Veridia, así que no hay progreso '
              'que recuperar. Si esperabas encontrar tus especies, '
              'seguramente elegiste otra cuenta de Google.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Usar otra cuenta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            // "aquí" y no "Crear cuenta nueva": la cuenta de Google ya
            // existe, lo que falta es el perfil de explorador en Veridia.
            // Con el texto anterior parecía que iba a abrir un formulario de
            // registro, y lo que hace es entrar.
            child: const Text('Crear mi cuenta aquí'),
          ),
        ],
      ),
    );
    return respuesta ?? false;
  }

  /// Deshace el acceso con una cuenta que no era la que se quería.
  ///
  /// Borrar de Firebase Auth la cuenta recién creada evita dejar cuentas
  /// fantasma; se puede hacer sin volver a pedir credenciales porque la
  /// autenticación acaba de ocurrir. Y `cerrarSesionGoogle()` es lo que hace
  /// que el selector de cuentas vuelva a salir: sin eso, Google reutiliza la
  /// misma cuenta en silencio y la persona no puede corregir su error.
  Future<void> _descartarCuentaNoRegistrada({
    required bool borrarDeAuth,
    bool avisar = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (borrarDeAuth && user != null) {
      try {
        await user.delete();
      } catch (e) {
        debugPrint('No se pudo borrar la cuenta recién creada: $e');
      }
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('No se pudo cerrar la sesión de Firebase: $e');
    }
    await cerrarSesionGoogle();

    // El aviso sobra cuando quien llama va a reabrir el selector de Google
    // acto seguido: se quedaría tapado por la ventana de Google, o peor, se
    // leería después de haber elegido ya la cuenta correcta.
    if (!avisar) return;
    if (!mounted) return;
    _mostrarAlerta('Elige la cuenta con la que te registraste en Veridia.');
  }

  Future<void> _signInWithGoogle() async {
    if (_selectedRole == 'Administrador') {
      return;
    }

    var didShowDialog = false;
    if (!mounted) return;
    didShowDialog = true;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: VeridiaLoader()),
      ),
    );

    try {
      final userCredential = await iniciarSesionConGoogle();
      // null = cerró la ventana de Google sin elegir cuenta: no es un error.
      if (userCredential == null) return;

      final cuentaGoogle = userCredential.user;
      if (cuentaGoogle == null) return;

      // Google autentica, pero no registra. Si esta cuenta no tiene perfil en
      // Veridia no se entra en silencio: es exactamente el caso de tocar por
      // error la cuenta equivocada en el selector de Google y acabar dentro de
      // una sesión vacía creyendo que se perdió todo el progreso.
      //
      // Se miran DOS señales porque ninguna basta sola: `isNewUser` detecta la
      // cuenta que Firebase acaba de crear en este mismo instante, y la
      // ausencia del documento detecta la que quedó huérfana de un intento
      // anterior (si el borrado de abajo falló, la segunda vez ya no sería
      // "nueva" y se colaría).
      final esCuentaNueva =
          userCredential.additionalUserInfo?.isNewUser == true;
      final tienePerfil = await UserRepository.instance.existePerfil(
        cuentaGoogle.uid,
      );

      if (esCuentaNueva || !tienePerfil) {
        if (didShowDialog && mounted) {
          Navigator.pop(context);
          didShowDialog = false;
        }
        if (!mounted) return;

        final quiereRegistrarse = await _preguntarPorCuentaNoRegistrada(
          cuentaGoogle.email ?? 'esta cuenta',
        );
        if (!quiereRegistrarse) {
          await _descartarCuentaNoRegistrada(
            borrarDeAuth: esCuentaNueva,
            avisar: false,
          );
          // Y se vuelve a abrir el selector de Google en el acto.
          //
          // Antes solo se limpiaba la sesión y se dejaba al explorador en la
          // pantalla de login con un aviso: tenía que volver a tocar "Iniciar
          // sesión con Google" él mismo, y como no había pasado nada visible
          // parecía que el botón no hacía nada. "Usar otra cuenta" tiene que
          // llevar a elegir otra cuenta, no a leer instrucciones.
          //
          // Se lanza SIN await y después de que esta llamada termine: así el
          // intento nuevo arranca limpio en vez de anidarse dentro del que lo
          // provocó, que dejaría dos diálogos de carga apilados.
          if (mounted) unawaited(_signInWithGoogle());
          return;
        }

        // "Crear mi cuenta aquí": se va al formulario de registro con el
        // correo y el nombre de Google ya puestos.
        //
        // ANTES hay que SOLTAR la sesión a medias. Google ya autenticó, así
        // que ese correo está ocupado en Firebase Auth: si se entrara al
        // formulario sin deshacerlo, registrarse con contraseña reventaría
        // con `email-already-in-use` sobre un correo que la propia app acaba
        // de crear. Soltándola, el formulario funciona por las dos vías —con
        // contraseña o con el botón "Registrarse con Google" de esa misma
        // pantalla—.
        final correo = cuentaGoogle.email;
        final nombre = cuentaGoogle.displayName;
        await _descartarCuentaNoRegistrada(
          borrarDeAuth: esCuentaNueva,
          avisar: false,
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RegisterScreen(correoInicial: correo, nombreInicial: nombre),
          ),
        );
        return;
      }

      await UserRepository.instance.initializeUser();

      if (didShowDialog && mounted) {
        Navigator.pop(context);
        didShowDialog = false;
      }

      if (mounted && userCredential.user != null) {
        await _handleAuthenticatedUser(userCredential.user!);
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        _mostrarAlerta(
          'Se agotó el tiempo esperando a Google (paso: ${e.message}). '
          'Intenta de nuevo.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        _mostrarAlerta('Esta cuenta ya existe con otro método de acceso.');
      } else {
        _mostrarAlerta('Error al iniciar sesión con Google. Intenta de nuevo.');
      }
    } catch (e) {
      debugPrint('Google Sign-In: error inesperado -> $e');
      if (mounted) {
        _mostrarAlerta('Error en la autenticación con Google.');
      }
    } finally {
      if (didShowDialog && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _lockTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _adminCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: VeridiaMontanas(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: const VeridiaSymbol(size: 104),
                        ),
                        const SizedBox(height: 20),
                        Text('Bienvenido de vuelta', style: text.headlineSmall),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa para seguir explorando la biodiversidad',
                          textAlign: TextAlign.center,
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 28),
                        VeridiaCard(
                          padding: const EdgeInsets.all(20),
                          glow: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SelectorRol(
                                valor: _selectedRole,
                                onChanged: (rol) =>
                                    setState(() => _selectedRole = rol),
                              ),
                              const SizedBox(height: 20),
                              VeridiaTextField(
                                controller: _emailController,
                                hintText: 'Correo electrónico',
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              VeridiaTextField(
                                controller: _passwordController,
                                hintText: 'Contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _iniciarSesion(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _olvideContrasena,
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                  ),
                                ),
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole == 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                          color: VeridiaColors.secondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'El rol Administrador requiere el '
                                            'código privado.',
                                            style: text.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Campo sensible: siempre oculto, sin ojo
                                    // de mostrar/ocultar.
                                    TextField(
                                      controller: _adminCodeController,
                                      obscureText: true,
                                      cursorColor: VeridiaColors.primary,
                                      style: text.bodyLarge,
                                      decoration: const InputDecoration(
                                        hintText: 'Código de administrador',
                                        prefixIcon: Icon(
                                          Icons.vpn_key_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              VeridiaBotonTactil(
                                child: FilledButton(
                                  onPressed: _segundosRestantesBloqueo > 0
                                      ? null
                                      : _iniciarSesion,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                  ),
                                  child: Text(
                                    _segundosRestantesBloqueo > 0
                                        ? 'Intenta de nuevo en '
                                              '${_segundosRestantesBloqueo}s'
                                        : 'Entrar',
                                  ),
                                ),
                              ),
                              AnimatedVisibility(
                                visible: _selectedRole != 'Administrador',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'o continúa con',
                                            style: text.labelSmall,
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    VeridiaBotonTactil(
                                      child: OutlinedButton.icon(
                                        onPressed: _signInWithGoogle,
                                        icon: const GoogleLogoIcon(size: 20),
                                        label: const Text(
                                          'Iniciar sesión con Google',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            double.infinity,
                                            52,
                                          ),
                                          foregroundColor:
                                              VeridiaColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    // Registrarse va DENTRO de la tarjeta y
                                    // con el mismo cuerpo que los otros dos.
                                    //
                                    // Suelto abajo y en letra pequeña se leía
                                    // como un pie de página, no como la
                                    // tercera forma de entrar que es. Mismo
                                    // alto (52) y mismo ancho completo que
                                    // "Entrar" y el de Google: las tres
                                    // maneras de pasar de esta pantalla se
                                    // ven como tres piezas del mismo tipo.
                                    //
                                    // Sigue siendo `OutlinedButton` y no
                                    // relleno: el relleno es de "Entrar", que
                                    // es lo que viene a hacer casi todo el
                                    // mundo aquí. Igualar el tamaño no es
                                    // igualar la jerarquía.
                                    const SizedBox(height: 12),
                                    VeridiaBotonTactil(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const RegisterScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.person_add_alt_1_outlined,
                                          size: 20,
                                        ),
                                        label: const Text('Crear una cuenta'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(
                                            double.infinity,
                                            52,
                                          ),
                                          foregroundColor:
                                              VeridiaColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conmutador Explorador / Administrador.
class _SelectorRol extends StatelessWidget {
  const _SelectorRol({required this.valor, required this.onChanged});

  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // Canal hundido con la pastilla elegida en relieve dentro: es el
        // mismo gesto del selector de la referencia.
        color: VeridiaColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(VeridiaRadii.pill),
        border: Border.all(
          color: VeridiaColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OpcionRol(
              label: 'Explorador',
              icon: Icons.travel_explore,
              seleccionado: valor == 'Explorador',
              onTap: () => onChanged('Explorador'),
            ),
          ),
          Expanded(
            child: _OpcionRol(
              label: 'Administrador',
              icon: Icons.admin_panel_settings_outlined,
              seleccionado: valor == 'Administrador',
              onTap: () => onChanged('Administrador'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionRol extends StatelessWidget {
  const _OpcionRol({
    required this.label,
    required this.icon,
    required this.seleccionado,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: seleccionado
              ? veridiaCaraClay(VeridiaColors.primaryContainer)
              : null,
          borderRadius: BorderRadius.circular(VeridiaRadii.pill),
          boxShadow: seleccionado ? veridiaRelieve() : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: seleccionado
                  ? VeridiaColors.onPrimaryContainer
                  : VeridiaColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: VeridiaFonts.headline,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: seleccionado
                      ? VeridiaColors.onPrimaryContainer
                      : VeridiaColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
