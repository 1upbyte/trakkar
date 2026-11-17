This is flutter_map_marker_cluster 8.2.2, copied from the published package
(https://github.com/lpongetti/flutter_map_marker_cluster). Its BSD license is
preserved in LICENSE.

Local changes in lib/src/marker_cluster_layer.dart:

- Identify an expanded cluster by its stable marker keys, rather than its
  geographic center, so incoming GPS fixes do not interrupt expansion.
- Refresh the expanded cluster reference after rebuilding nodes so callbacks use
  current marker data and tapping the group collapses it immediately.
- Use the same membership check when handling cluster taps.

The entry library also omits its unnecessary name to pass the app's lint rules.

Unkeyed markers retain the upstream geographic-center matching behavior. Zooming
still collapses expanded clusters. No location updates are delayed or discarded.

Regression coverage lives in test/screens/cluster_live_update_test.dart in the
app. The package's three upstream test files are retained here as well.
