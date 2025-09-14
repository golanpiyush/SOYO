import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDropdown<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) displayText;
  final Function(T) onChanged;
  final Widget? Function(T)? trailing;
  final double? maxHeight;

  const CustomDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.displayText,
    required this.onChanged,
    this.trailing,
    this.maxHeight,
  }) : super(key: key);

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _closeDropdown();
    super.dispose();
  }

  void _toggleDropdown() {
    print('Toggle called, isOpen: $_isOpen'); // Debug print
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (_isOpen) return;

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(offset, size),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    if (!_isOpen) return;

    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
    setState(() => _isOpen = false);
  }

  Widget _buildOverlay(Offset offset, Size size) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownMaxHeight = widget.maxHeight ?? 300.0;

    // Calculate available space above and below
    final spaceBelow = screenHeight - offset.dy - size.height - 20;
    final spaceAbove = offset.dy - 20;

    // Determine if dropdown should appear above or below
    final showAbove = spaceBelow < dropdownMaxHeight && spaceAbove > spaceBelow;

    // Calculate actual dropdown height
    final itemHeight = 56.0;
    final calculatedHeight = (widget.items.length * itemHeight).clamp(
      0.0,
      dropdownMaxHeight,
    );
    final dropdownHeight = calculatedHeight;

    // Calculate position
    double top;
    if (showAbove) {
      top = offset.dy - dropdownHeight - 8;
    } else {
      top = offset.dy + size.height + 8;
    }

    // Ensure dropdown doesn't go off screen
    top = top.clamp(20.0, screenHeight - dropdownHeight - 20);

    return GestureDetector(
      onTap: _closeDropdown,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Background overlay
            Container(
              width: screenWidth,
              height: screenHeight,
              color: Colors.black.withOpacity(0.2),
            ),
            // Dropdown content
            Positioned(
              left: offset.dx,
              top: top,
              width: size.width,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * _animation.value),
                    alignment: showAbove
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    child: Opacity(opacity: _animation.value, child: child),
                  );
                },
                child: Container(
                  constraints: BoxConstraints(maxHeight: dropdownHeight),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[700]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: Colors.transparent,
                      child: widget.items.length > 8
                          ? Scrollbar(
                              thumbVisibility: true,
                              radius: const Radius.circular(8),
                              child: _buildDropdownList(),
                            )
                          : _buildDropdownList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = item == widget.value;

        return InkWell(
          onTap: () {
            widget.onChanged(item);
            _closeDropdown();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              border: isSelected
                  ? Border(left: BorderSide(color: Colors.blue, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.displayText(item),
                    style: GoogleFonts.nunito(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.trailing != null)
                  widget.trailing!(item) ?? const SizedBox.shrink(),
                if (isSelected) Icon(Icons.check, color: Colors.blue, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isOpen
              ? Colors.grey[800]!.withOpacity(0.8)
              : Colors.grey[900]!.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isOpen ? Colors.blue.withOpacity(0.5) : Colors.grey[700]!,
            width: _isOpen ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.nunito(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.displayText(widget.value),
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: _isOpen ? Colors.blue : Colors.grey[400],
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
