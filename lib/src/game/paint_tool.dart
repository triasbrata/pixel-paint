/// How a tap on the grid paints.
enum PaintTool {
  /// One cell at a time (drag to paint a line).
  pencil,

  /// The tapped cell and every touching cell with the same number.
  fill,
}
