# Changelog

## 2.17.3

### Added
- Links to Vlog: Let's make an actual game (in the Video Explainers tab)
- Flip buttons for your `ScalableVectorShape2D`'s path / primitives next to the uniform transform buttons
- Use the new `ScalableVectorShape2D.glue_map` to assign a `Node2D` to a point in the `curve`.

### Changed
- Moved logic for image export to helper class `SVSSceneExporter.export_image`
- Moved logic for animation sprite frames export to `SVSSceneExporter.export_sprite_frames`

## 2.16.3

### Added
- Uniform transformation buttons (move/rotate/scale all points without changing `Node2D.transform`)
- The `spin` property to represent a Rectangle / Ellipse primitive's local rotation.
- The `ScalableVectorShape2D.get_center()` method, which simply returns the center of the bounding rect of the shape

### Changed
- Use `Curve2D.set_block_signals` to update all points at once in `ScalableVectorShape2D.set_ellipse_points`
- Use `Curve2D.set_block_signals` to update all points at once in `ScalableVectorShape2D.set_rect_points`
- Bugfix: collision objects and navigation region are also added when neither fill, nor stroke is assigned
- Bugfix: collision objects and navigation region are now also owned when created for a ScalableVectorShape2D that is also the scene root.
- Bugfix: rotate around natural center is now predictable by using remembering the bounding rect center before starting to rotate

## 2.15.0

### Added
- Auto-scaling for SVG image icons on GUI controls (`Button`, `TextureButton`, `TextureRect`) using `SVGTextureHelper` (thank you to @kcfresh53)

### Changed
- Dropped class_names from GUI items in plugin itself to prevent cluttering up developers' `add node` dialog

## 2.14.3

### Added
- Bake Animation as Sprite Frames (under Advanced Editing tab) as a PNG spritesheet, or separate PNG files.
- Video explainer tab with some youtube links
- Center 2D viewport around newly created shapes...
- ...and around newly imported SVG Files

### Changed
- Bugfix: pause animation player before snapshotting sprite frame (from 2.14.0)
- Bugfix: svg importer must await first render frame before baking when not importing as `ScalableVectorShape2D`

## 2.13.4

### Changed
- Bugfix: race conditions due to unsafe pass by reference when setting `Polygon2D.polygon` in combination with `Polygon2D.polygons`
- Performance tweak: no more unnecessary invocations of `Geometry2DUtil.calculate_poly_strokes`


## 2.13.3

### Added
- New node type `AdaptableVectorShape3D` of which the shape can be changed via an assigned `ScalableVectorShape2D`
- New form `Curve Settings` added under tab `Project Settings`

### Changed
- Bugfix: svg importer now positions clip-paths correctly by using the same parent (`<g>`-node) as the clipped shape
- Bugfix: calculate polygons at max once per frame (major performance fix for animations)
- Adds tab `Project Settings`
- Moves `Editor Settings` to tab `Project Settings`
- Flags property `update_curve_at_runtime` on by default (changeable in `Curve Settings`)
- Flags property `resource_local_to_scene` on by default (changeable in `Curve Settings`)


## 2.13.0 - 2025-08-28

### Added
- Advanced tab in bottom panel with 3 export buttons usable on any type of selected node: PNG, Baked, 3D Scene
- Export as 3D scene (all Fills and Strokes are turned into `CSGPolygon2D` instances)

### Changed
- Bugfix: removed infinite recursion when exporting a scene root as 'Baked Scene'


## 2.12.3 - 2025-08-23

### Added
- You can now also use Polygon2D for Strokes using the `poly_stroke` property
- Collision Objects will now also get `CollisionPolygon2D`s for strokes
- Adds `signal polygons_updated(polygons: Array[PackedVector2Array], poly_strokes: Array[PackedVector2Array], self_ref : ScalableVectorShape2D)`

### Changed
- Reverts hiding of the Collision Polygon property field
- Fix: position of new shapes is now always Vector2.ZERO
- In the Stroke Inspector plugin, stroke properties are now edited on `ScalableVectorShape2D` in stead of its assigned `Line2D`:
  - `line.default_color` -> `stroke_color`
  - `line.width` -> `stroke_width`
  - `line.begin_cap_mode` -> `begin_cap_mode`
  - `line.end_cap_mode` -> `end_cap_mode`
  - `line.joint_mode` -> `line_joint_mode`
- ⚠️ Please note that keyframes for all these properties are now set on `ScalableVectorShape2D` directly in stead of the assigned `Line2D`
- Fix edge cases where holes resulting from geometry operations are not handled correctly
- Rat's return example uses new signal to allow all blocks sharing the same `StaticBody2D`

## 2.11.5 - 2025-18-08

### Added
- Snap to pixel when adding points
- Snap to pixel when dragging curve edges
- Snap to pixel when dragging gradient stops
- Snap to pixel when changing rx/ry and size of primitive shapes

### Changed
- Export as 'baked' scene now supports cutouts, clips and merged shapes
- Import SVG as Node2D in stead of ScalableVectorShape2D now works with cutouts, clips and merged shapes
- Export buttons moved to inspector group `ScalableVectorShape2D > Export Options` to save screen real-estate

## 2.11.3 - 2025-14-08

### Added
- SVG Importer now supports `<clipPath>`, `<use>` and embedded base64 encoded `<image>` (results may vary)

### Changed
- Use Pascal case in stead of Camel case to represent imported svg file names
- Rename dock nodes in order to reference them with unique name

## 2.11.2 - 2025-10-08

### Added
- Shortcut `Ctrl+Shift+Mousewheel` to pick cutout shape
- Shortcut `Ctrl+Shift+Right click` to change clipping operation
- 'Rat's return' (examples/rats_return.tscn) to illustrate shape manipulation programmatically
- `Export as baked scene` button.
- Flag `use_union_in_stead_of_clipping` to `ScalableVectorShape2D` which turns a cutout into a merged shape
- Convenience method `clipped_polygon_has_point(global_pos : Vector2)` to detect clicks __on__ a shape without the click being in a hole
- A bubbly cloud example to illustrate `use_union_in_stead_of_clipping`

### Changed
- Separates out the calculation of outlines and fixes most issues with it (holes within holes not working yet)
- Can now cut holes in ellipses using right click in the add shapes programatically example.

## 2.11.0 - 2025-06-08

### Added
- Preparations for svg clipPath support by adding flag `use_intersect_when_clipping` to `ScalableVectorShape2D` which turns a cutout into a clip_path by invoking `Geometry2D.intersect_polygons(...)` in stead of `Geometry2D.clip_polygons(...)`

### Changed
- Bugfix: svg importer can now also use gradients defined _after_ the element referring to it via `href`

## 2.10.4 - 2025-04-08

### Added
- Mac users can now use the Cmd key in stead of Ctrl key

### Changed
- Bugfix: SVG importer can now handle rgb() and rgba() colors for stroke and fill
- Bugfix: Style attribute of root element not is ignored anymore
- SVG importer evaluates all cutouts for a shape at once
- ScalableVectorShape2D caches outlines after tessellate and only reinvokes tessellate when the curve actually changes
- Only recalculate curve when local transform of cutout changes (cutout has to be direct child of parent for this to trigger correctly)
- Prevent global position form from being visible when plugin is enabled
- Bugfix: order of undo/redo operations fixed for dragging operations

## 2.10.2 - 2025-02-08

### Added
- You can now import an SVG file into any type of opened scene (3D, GUI, Node)
- You can now create a new ScalableVectorShape2D in any type of opened scene

### Changed
- Using uniqe names in stead of `find_node` to refer to tool controls
- SVG importer only creates cutout when initial point of follow-up path is _inside_ first shape
- Bugfix: svg transform attribute now supports multiple transform commands
- Bugfix: can now perform svg transform translate(...) with one parameter as well as two
- Bugfix: resets the cursor position of follow-up paths correcty now (after the z/Z command)
- Bugfix: SVG importer sets rx/ry values compliantly now

## 2.9.1 - 2025-27-07

### Added
- Use Ctrl+Shift+Left click to create a cutout shape for the selected shape
- One shape can have multiple cutout shapes assigned (via the `clip_paths` property)
- Cutouts can be holes, made possible by multiple polygons
- Cutouts are `ScalableVectorShape2D` nodes themselves with all the same capabilities
- A `NavigationRegion2D` can now be assigned via the `navigation_region` property
- The SVG importer now also supports cutout paths within the `d="..."` attribute (results may vary)

## 2.8.2 - 2025-21-07

### Added
- The `collision_object` property is meant to replace the `collision_polygon` property
- This will hold an assignment to a descendant of `CollisionObject2D` (`Area2D`, `StaticBody2D`, etcetera)
- This managed `CollisionObject2D` will get directly generated `Polygon2D` children from the plugin

### Changed
- The `collision_polygon` property is now marked as deprecated (but will function the same for backward compatibility)
- Bugfix: fixed parsing bug for quadratic bézier curves

### Removed
- Removed the assignment inspector form field for the `collision_polygon` property once it has been unassigned

## 2.7.1 - 2025-16-07

### Added
- Add direct arc support for ScalableVectorShape2D: moving arcs around is now much easier by replacing many points by just the 2 (start and end)
- The arcs can be dynamically manipulated via metadata fields (radius, rotation, large arc, sweep -> see: [svg specification](https://www.w3.org/TR/SVG/paths.html#PathDataEllipticalArcCommands))
- The arcs can also be animated using the `Curve Settings > Batch insert` button for key frames


### Changed
- Bugfix: fixed index out of bounds for scale-transform in svg importer.
- Removed `Rat` class_name from the rat example to prevent name conflicts.

## 2.6.6 - 2025-11-07

### Changed
- Bugfix: SVG importer can now handle negative numbers without leading whitespace
- Bugfix: SVG importer now handles multiple shapes in one svg path element

## 2.6.5 - 2025-10-07

### Added
- SVG importer now supports the arc command (fixed at 4 degree angles for now)

## 2.6.4 - 2025-01-07

### Changed
- ScalableVectorShape2D nodes can only be selected when mousedown and mouseup event registered on the same node ('click'-event)
- ScalableVectorShape2D nodes can now only be selected when they are visible
- ScalableVectorShape2D nodes can not be selected anymore when they are locked using the lock-icon
- ScalableVectorShape2D nodes can not be selected anymore when they are part of a different scene

## 2.6.3 - 2025-06-15

### Added
- Change line-capping of strokes via inspector
- Change line-joining of strokes via inspector
- Pick default line-cap and line-join modes for creating new strokes
- Maps line-join modes and line-cap modes from SVG to Godot using the importer
- Pixel snap mode checkbox, disabled by default
- Show point positions under editor hints
- Form to set exact global position for curve point and handles (in path mode)
- Export as PNG button in inspector form of ScalableVectorShape2D

### Changed
- "Show point numbers" renamed to "Show point details", also toggles position info on/off

## 2.5.2 - 2025-06-08

### Added
- Makes Rectangles editable using one size handle and two rounded corner handles
- Makes Ellipses editable using one size handle
- Adds create buttons for Rectangle as Rectangle and Ellipse as Ellipse
- ..next to exists create buttons for them as Path
- Adds a "convert to path" button in the inspector when `shape_type` is a rectangle or ellipse

### Changed

- Enhancement: newly created Rectangle has its origin at its natural center, in stead of its top/left corner
- Bugfix: gradient stop color order stays in tact after undo remove
- Bugfix: Bottom Panel is more visible after fresh install
- Bugfix: preloading replaced by loading to fix busy resource issues in inspector plugin code
- Bugfix: previewed shape has scaled stroke

### Removed
- Custom collapse / expand titles from inspector plugin forms in favour of `@export_group` annotations on `ScalableVectorShape2D`

## 2.4.3 - 2025-06-07

### Changed
- Fixed a preloading + busy device bug in inspector plugin load script

## 2.4.2 - 2025-06-05

### Added
- Batch insert key frame button for entire curve
- Batch insert key frame button for entire gradient
- Key frame button for stroke width
- Key frame button for fill stroke color
- Key frame button for fill color

### Changed
- Fixes ordering bug of gradient stop color buttons
- Reconnects import svg button to file dialog in svg importer panel

## 2.3.2 - 2025-05-31

### Added
- Adds gradient fill toggle to the inspector form
- Adds gradient stop color buttons to the inspector form
- Adds gradient start- and end handle to 2D editor
- Adds stop color handles to 2D editor
- Implements paint-order correctly in SVG importer
- Better tooltips for SVG importer
- Warning message for unsupported clipping (using 'm'- / 'M'-operator) in SVG importer

### Changed
- Bugfix: resizes the gradient texture when the bounding box changes
- Regression fix: all the SVG importer settings in the SVG importer form work again

## 2.2.1 - 2025-05-28

### Added
- Adds easier to use forms for Stroke, Fill and Collision shape to the `ScalableVectorShape2D` inspector
- Adds project settings for defaults like stroke width, stroke and fill colors, and paint order
- Separates the point numbers from the hint labels
- Saves project settings for enabling and disabling hints and viewport editing
- Shows a preview of the shape which is about to be added via the bottom panel
- Explanatory tooltips for all the fields and options that are not self-explanatory enough


## 2.1.3 - 2025-05-24

### Added
- Undo/Redo for strokes (`Line2D`) fills (`Polygon2D`) and collisions (`CollisionPolygon2D`) added with the `Generate` button in the inspector
- After Undo of creating a new shape from the bottom panel, its parent node is automatically selected again
- Resize a shape without using the `scale` property using `Shift+mousewheel`, for more pixel perfect alignment


### Changed
- Fix: after adding point on line with double click, the correct point is removed again with undo
- Fix: when a curve is closed, it stroke (the `Line2D` assigned to the `line`-property) is also closed and vice-versa
- Fix: closing a shape now works by simply adding a segement between the last and first point

## 2.1.0 - 2025-05-21

### Added
- Use `Ctrl+click` to add points to a shape faster
- Undo/Redo support for shapes from the bottom panel

### Changed
- Shapes from the bottom panel are added as child of the selected node
- When no node is selected, shapes from the bottom panel are added in the center of the viewport
- Batched Undo/Redo for all mouse drag operations
- Tooltip and ability to copy link with right click on `LinkButton` to external content


## 2.0.0 - 2025-05-19

### Added

- Custom node `ScalableVectorShape2D` introduced, enabling editing of its `Curve2D` using the mouse similar to the popular open source vector drawing program [Inkscape](https://inkscape.org/)
- Add a circle, ellipse or rectangle from the bottom panel directly
- Ability to Undo/Redo many drawing operations
- A more comprehensive manual in the [README](./README.md)

### Changed

- The custom node `DrawablePath2D` was deprecated in favor of `ScalableVectorShape2D`


## 1.3.0 - 2025-05-10

_Last stable release of EZ Curved Lines 2D_

This shipped 2 things:

- An SVG file importer, which transforms shapes into native Godot nodes
- The custom node `DrawablePath2D`, which extends from Godot's `Path2D` to use its built-in `Curve2D` editor
