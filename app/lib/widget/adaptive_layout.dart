// Rhizu Adaptive Layout Exports
// Provides expressive-design components and adaptive layouts

// Re-export all rhizu components for convenience
export 'package:rhizu/rhizu.dart';

// Additional convenience exports for common layout patterns
// These provide type-safe, expressive-design based layouts
// that adapt to different screen sizes automatically

// Usage examples:
//
// 1. List-Detail Layout (for master-detail views):
//    ListDetailLayout(
//      list: DeviceList(),
//      detail: DeviceDetails(),
//      isDetailVisible: selectedDevice != null,
//    )
//
// 2. Supporting Pane Layout (for additional context):
//    SupportingPaneLayout(
//      main: MainContent(),
//      supporting: SidePanel(),
//    )
//
// 3. Feed Layout (for responsive grids):
//    FeedLayout(
//      itemCount: items.length,
//      itemBuilder: (context, index) => ItemCard(items[index]),
//    )
