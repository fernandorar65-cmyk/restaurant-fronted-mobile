import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../../../widgets/base/base_button.dart';
import '../../../widgets/navigation/theme_menu.dart';
import '../../auth/brand.dart';

const _nav = [
  (id: 'funciones', label: 'Funciones'),
  (id: 'como-funciona', label: 'Cómo funciona'),
  (id: 'clientes', label: 'Para tus clientes'),
  (id: 'preguntas', label: 'Preguntas'),
];

/// Lo que el sistema ya incluye hoy, agrupado como lo vería un dueño.
const _features = [
  (
    title: 'Carta digital y QR por mesa',
    description: 'Publica tu carta con fotos, ingredientes, alérgenos y tiempos. Cada mesa tiene su QR para pedir sin esperar.',
    icon: Icons.qr_code_2_rounded,
  ),
  (
    title: 'Pedidos y cocina en tiempo real',
    description: 'Los pedidos llegan al instante a sala y a la cola de cocina, con estados claros desde que se piden hasta que se sirven.',
    icon: Icons.bolt_rounded,
  ),
  (
    title: 'Delivery y pedido anticipado',
    description: 'Tus clientes piden para llevar o para tenerlo listo al llegar. Define radio de entrega, costo de envío y pedido mínimo.',
    icon: Icons.local_shipping_outlined,
  ),
  (
    title: 'Cuentas y cobros',
    description: 'Cuentas por mesa y opciones de pago con tarjeta, Yape, Plin y transferencia, todo en un mismo lugar.',
    icon: Icons.credit_card_rounded,
  ),
  (
    title: 'Métricas y cierre del día',
    description: 'Ventas, ticket promedio y ocupación de cada sede. Cierra la caja del día con un resumen listo para revisar.',
    icon: Icons.bar_chart_rounded,
  ),
  (
    title: 'Varias sedes, roles y personal',
    description: 'Gestiona todas tus sedes desde una cuenta. Cocina, sala y caja ven solo lo que necesitan según su rol.',
    icon: Icons.groups_outlined,
  ),
  (
    title: 'Gestión de mesas',
    description: 'Plano de sala con el estado de cada mesa: libre, ocupada, reservada o en limpieza. Imprime los QR en un clic.',
    icon: Icons.table_restaurant_outlined,
  ),
  (
    title: 'Inventario',
    description: 'Controla tus insumos y recibe avisos cuando algo se está acabando, antes de que afecte al servicio.',
    icon: Icons.inventory_2_outlined,
  ),
];

const _steps = [
  (title: 'Registra tu restaurante', description: 'Crea tu cuenta de dueño y agrega tus sedes con su dirección y horarios.'),
  (title: 'Sube tu carta e imprime los QR', description: 'Carga tus platos con fotos y precios. Genera el QR de cada mesa y colócalo.'),
  (title: 'Recibe pedidos', description: 'Tus clientes piden desde su celular; sala, cocina y caja trabajan coordinados.'),
];

const _dinerPoints = [
  'Encuentran tu restaurante en un mapa con los locales más cercanos.',
  'Buscan platos al escribir, por nombre o ingrediente, aunque no pongan tildes.',
  'Ven ingredientes, presentación, porción y tiempo de cada plato antes de pedir.',
  'Guardan sus alergias y preferencias en su perfil.',
  'Eligen comer en mesa, recoger al llegar o delivery, y pagan desde el celular.',
];

const _faqs = [
  (
    question: '¿Necesito comprar equipos especiales?',
    answer: 'No. Funciona en el navegador de cualquier celular, tablet o computadora. Para la cocina basta una pantalla con internet.',
  ),
  (
    question: '¿Mis clientes tienen que descargar una app?',
    answer: 'No. Escanean el QR de la mesa o entran desde el enlace de tu restaurante y piden desde el navegador.',
  ),
  (
    question: '¿Puedo gestionar varios locales?',
    answer: 'Sí. Desde una sola cuenta administras todas tus sedes, cada una con su carta, sus mesas y su personal.',
  ),
  (
    question: '¿Puedo limitar lo que ve cada empleado?',
    answer: 'Sí. Cada rol tiene sus permisos: cocina ve la cola de pedidos, caja ve las cuentas y la gerencia ve las métricas.',
  ),
  (
    question: '¿Puedo ofrecer delivery solo en algunas sedes?',
    answer: 'Sí. En cada sede eliges si atiende en mesa, pedido anticipado o delivery, con su propio radio de entrega y costo de envío.',
  ),
];

/// Tarjetas "en vivo" de la portada: rotan pedidos, pagos y la cola de cocina.
const _liveOrders = [
  (title: 'Mesa 4 · 3 platos', detail: 'Croquetas, rabo de toro, manzanilla'),
  (title: 'Delivery D-2041 · 2 platos', detail: 'Risotto de setas, soufflé'),
  (title: 'Recoge 13:30 · 4 platos', detail: 'Jamón ibérico, pescaíto frito…'),
  (title: 'Mesa 9 · 2 platos', detail: 'Vieira a la brasa, copa de champán'),
];
const _livePayments = ['Yape · Mesa 12', 'Tarjeta · Mesa 3', 'Plin · R-1042', 'Transferencia · D-2041'];
const _liveKitchen = [5, 6, 4, 7];

const _dishImageUrl = 'https://upload.wikimedia.org/wikipedia/commons/2/29/Croquetas_caseras_de_jam%C3%B3n_en_Salamanca.jpg';

/// Landing comercial para dueños de restaurante. Pública y sin layout propio.
class RestaurantLandingView extends StatefulWidget {
  const RestaurantLandingView({super.key});

  @override
  State<RestaurantLandingView> createState() => _RestaurantLandingViewState();
}

class _RestaurantLandingViewState extends State<RestaurantLandingView> {
  final Map<String, GlobalKey> _sectionKeys = {for (final item in _nav) item.id: GlobalKey()};
  int? _openFaq = 0;
  int _liveIndex = 0;
  Timer? _liveTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien pidió menos movimiento en su sistema ve todo estático.
    if (MediaQuery.of(context).disableAnimations) {
      _liveTimer?.cancel();
      _liveTimer = null;
    } else {
      _liveTimer ??= Timer.periodic(const Duration(milliseconds: 3200), (_) {
        if (mounted) setState(() => _liveIndex = (_liveIndex + 1) % _liveOrders.length);
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _goToSection(String id) {
    final target = _sectionKeys[id]?.currentContext;

    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        // El encabezado gana sombra al desplazarse.
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        titleSpacing: 12,
        title: Semantics(
          label: 'RentaSol, ir al inicio',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(Routes.home),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.menu_book_outlined, size: 20, color: c.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text('RentaSol', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          const ThemeMenu(),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => context.go(Routes.login),
            child: Text('Iniciar sesión', style: AppFonts.label(fontSize: 14, color: c.onSurface)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: Semantics(
              label: 'Secciones',
              container: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: _nav.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _nav[index];
                  return ActionChip(label: Text(item.label), onPressed: () => _goToSection(item.id));
                },
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(c),
            _section(
              key: _sectionKeys['funciones'],
              background: c.surfaceContainerLow,
              eyebrow: 'Qué incluye',
              title: 'Todo lo que necesita tu servicio',
              subtitle: 'Desde que el cliente abre la carta hasta que cierras la caja del día.',
              child: Column(
                children: [
                  for (final feature in _features) ...[
                    _FeatureCard(title: feature.title, description: feature.description, icon: feature.icon),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            _section(
              key: _sectionKeys['como-funciona'],
              eyebrow: 'Cómo funciona',
              title: 'Empieza en tres pasos',
              child: Column(
                children: [
                  for (var index = 0; index < _steps.length; index++)
                    _StepItem(
                      number: index + 1,
                      title: _steps[index].title,
                      description: _steps[index].description,
                      isLast: index == _steps.length - 1,
                    ),
                ],
              ),
            ),
            _section(
              key: _sectionKeys['clientes'],
              background: c.surfaceContainerLow,
              eyebrow: 'Para tus clientes',
              title: 'Una experiencia que dan ganas de repetir',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final point in _dinerPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20, color: c.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Text(point, style: TextStyle(fontSize: 15, color: c.onSurfaceVariant, height: 1.4))),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                      onPressed: () => context.go(Routes.home),
                      child: Text('Probar la experiencia del cliente →', style: AppFonts.label(fontSize: 15, color: c.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ExcludeSemantics(child: _DishMockup()),
                ],
              ),
            ),
            _section(
              key: _sectionKeys['preguntas'],
              eyebrow: 'Preguntas frecuentes',
              title: 'Lo que suelen preguntarnos',
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < _faqs.length; index++) ...[
                      if (index > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: 0.5)),
                      _FaqItem(
                        question: _faqs[index].question,
                        answer: _faqs[index].answer,
                        open: _openFaq == index,
                        onTap: () => setState(() => _openFaq = _openFaq == index ? null : index),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _finalCta(c),
            _footer(c),
          ],
        ),
      ),
    );
  }

  Widget _hero(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: c.tertiaryFixed, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: c.tertiary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Para restaurantes', style: AppFonts.label(fontSize: 12, color: c.onTertiaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: 'Tu restaurante conectado, ',
              children: [
                TextSpan(text: 'de la mesa a la cocina', style: TextStyle(fontStyle: FontStyle.italic, color: c.primary)),
                const TextSpan(text: '.'),
              ],
            ),
            style: AppFonts.headline(fontSize: 34, color: c.onSurface, height: 1.15),
          ),
          const SizedBox(height: 16),
          Text(
            'RentaSol reúne tu carta digital, los pedidos por QR, la cocina, los cobros, el delivery y las métricas de todas tus '
            'sedes en un solo lugar.',
            style: TextStyle(fontSize: 16, color: c.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          BaseButton(
            label: 'Registrar mi restaurante',
            variant: 'primary',
            size: 'lg',
            block: true,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => context.go(Routes.register),
          ),
          const SizedBox(height: 8),
          BaseButton(label: 'Ver cómo lo usan los clientes', size: 'lg', block: true, onPressed: () => context.go(Routes.home)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final item in const ['Sin apps que instalar', 'Funciona en cualquier dispositivo', 'Varias sedes en una cuenta'])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: c.success),
                    const SizedBox(width: 6),
                    Text(item, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 28),
          ExcludeSemantics(child: _heroVisual(c)),
        ],
      ),
    );
  }

  /// Foto con tarjetas "en vivo" que rotan.
  Widget _heroVisual(AppColors c) {
    final order = _liveOrders[_liveIndex];
    Widget swap(Widget child) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: child,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              authShowcaseImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => ColoredBox(color: c.surfaceContainer),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LiveCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('NUEVO PEDIDO', style: AppFonts.eyebrow(color: c.success)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      swap(
                        Column(
                          key: ValueKey(_liveIndex),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface)),
                            Text(order.detail, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LiveCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: c.success),
                                const SizedBox(width: 6),
                                Text('Pago recibido', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            swap(
                              Text(
                                _livePayments[_liveIndex],
                                key: ValueKey(_liveIndex),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LiveCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cola de cocina', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                swap(
                                  Text(
                                    '${_liveKitchen[_liveIndex]}',
                                    key: ValueKey(_liveIndex),
                                    style: AppFonts.headline(fontSize: 22, color: c.onSurface),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(child: Text('en preparación', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section({
    Key? key,
    Color? background,
    required String eyebrow,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final c = context.colors;

    return Container(
      key: key,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(eyebrow.toUpperCase(), style: AppFonts.eyebrow(color: c.tertiary)),
          const SizedBox(height: 8),
          Text(title, style: AppFonts.headline(fontSize: 28, color: c.onSurface, height: 1.2)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 15, color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _finalCta(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Image.network(
                  authShowcaseImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => ColoredBox(color: c.primary),
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0xB3000000))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Lleva tu restaurante a RentaSol', style: AppFonts.headline(fontSize: 26, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta, sube tu carta y empieza a recibir pedidos.',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 20),
                  BaseButton(
                    label: 'Registrar mi restaurante',
                    variant: 'primary',
                    size: 'lg',
                    block: true,
                    onPressed: () => context.go(Routes.register),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x99FFFFFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.go(Routes.login),
                    child: Text('Ya tengo cuenta', style: AppFonts.label(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(AppColors c) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('© ${DateTime.now().year} RentaSol', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                    onPressed: () => context.go(Routes.home),
                    child: Text('Para clientes', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => context.go(Routes.login),
                    child: Text('Acceso del personal', style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x261B1C1D), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.primaryFixed, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c.onPrimaryFixed),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppFonts.headline(fontSize: 17, color: c.onSurface)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.number, required this.title, required this.description, required this.isLast});

  final int number;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Text('$number', style: AppFonts.headline(fontSize: 18, color: c.onPrimary)),
              ),
              // Línea que une los pasos.
              if (!isLast) Expanded(child: Container(width: 2, color: c.outlineVariant)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer, required this.open, required this.onTap});

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(question, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.onSurface)),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Apertura suave.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(answer, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant, height: 1.5)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Maqueta de un plato en la app.
class _DishMockup extends StatelessWidget {
  const _DishMockup();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget overlayChip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
          child: Text(text, style: AppFonts.label(fontSize: 12, color: Colors.white)),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x261B1C1D), blurRadius: 32, offset: Offset(0, 12))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _dishImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => ColoredBox(color: c.surfaceContainer),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Row(children: [overlayChip('10 min'), const SizedBox(width: 6), overlayChip('6 unidades')]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Croquetas de jamón ibérico', style: AppFonts.headline(fontSize: 18, color: c.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      'Bechamel lenta de leche entera y jamón ibérico, crujientes por fuera y cremosas por dentro.',
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in const ['Jamón ibérico', 'Leche entera', 'Pan rallado'])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                            child: Text(item, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: Text('+ Agregar a la orden', style: AppFonts.label(fontSize: 14, color: c.onPrimary))),
                          Text('11,00 €', style: AppFonts.label(fontSize: 14, color: c.onPrimary)),
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
    );
  }
}
