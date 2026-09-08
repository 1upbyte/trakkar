import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'map_screen.dart';
import 'people_screen.dart';
import 'places_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      state.setAppForeground(true);
      state.refreshTrackingHealth();
      state.setMapForeground(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _appState?.setAppForeground(state == AppLifecycleState.resumed);
    _syncMapForeground();
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().refreshTrackingHealth();
    }
  }

  void _syncMapForeground() {
    _appState?.setMapForeground(
      _index == 0 && _lifecycleState == AppLifecycleState.resumed,
    );
  }

  void _selectDestination(int value) {
    if (_index == value) return;
    setState(() => _index = value);
    _syncMapForeground();
  }

  @override
  void dispose() {
    _appState?.setMapForeground(false);
    _appState?.setAppForeground(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _selectDestination(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            _TabStack(
              index: _index,
              children: [
                MapScreen(
                  visible: _index == 0,
                  onPeopleTap: () => _selectDestination(1),
                ),
                const PeopleScreen(),
                const PlacesScreen(),
                const SettingsScreen(),
              ],
            ),
            if (state.exitAlert != null ||
                state.trackingHealth.hasWarning ||
                state.lastError != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.exitAlert != null)
                      _ExitAlertBanner(
                        message: state.exitAlert!,
                        onDismiss: state.dismissExitAlert,
                      ),
                    if (state.exitAlert != null &&
                        (state.trackingHealth.hasWarning ||
                            state.lastError != null))
                      const SizedBox(height: 8),
                    if (state.trackingHealth.hasWarning)
                      _TrackingHealthBanner(state: state),
                    if (state.trackingHealth.hasWarning &&
                        state.lastError != null)
                      const SizedBox(height: 8),
                    if (state.lastError != null)
                      _ErrorBanner(message: state.lastError!),
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group_rounded),
              label: 'People',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place_rounded),
              label: 'Places',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitAlertBanner extends StatelessWidget {
  const _ExitAlertBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: ListTile(
        leading: Icon(
          Icons.notifications_active_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: IconButton(
          tooltip: 'Dismiss alert',
          onPressed: onDismiss,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _TrackingHealthBanner extends StatelessWidget {
  const _TrackingHealthBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final health = state.trackingHealth;
    final details = <String>[
      if (health.needsLocation) 'set Location to Always / Allow all the time',
      if (health.needsActivity) 'allow the Physical activity permission',
      if (health.needsBattery)
        'set battery use to Unrestricted / Not optimized',
    ];
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Background tracking may stop: ${details.join(' and ')}.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                if (health.needsLocation || health.needsActivity)
                  TextButton(
                    onPressed: state.openLocationSettings,
                    child: const Text('Permission settings'),
                  ),
                if (health.needsBattery)
                  TextButton(
                    onPressed: state.openBatterySettings,
                    child: const Text('Battery settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps each tab's map camera, scroll position, and form state alive.
class _TabStack extends StatelessWidget {
  const _TabStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _TabPane(active: index == i, child: children[i]),
      ],
    );
  }
}

class _TabPane extends StatefulWidget {
  const _TabPane({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<_TabPane> {
  late bool _hidden = !widget.active;

  @override
  void didUpdateWidget(covariant _TabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _hidden = false;
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Offstage(
      offstage: reducedMotion ? !widget.active : _hidden,
      child: TickerMode(
        enabled: !_hidden,
        child: IgnorePointer(
          ignoring: !widget.active,
          child: ExcludeSemantics(
            excluding: !widget.active,
            child: AnimatedOpacity(
              opacity: widget.active ? 1 : 0,
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (!widget.active) setState(() => _hidden = true);
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
