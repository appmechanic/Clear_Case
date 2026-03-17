import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ignore: must_be_immutable
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode node;
  final FocusNode? nextNode;
  final String labelText;
  final IconData? icon;
  final int maxLines;

  final Color backgroundColor;
  final Color borderActiveColor;
  final Color textColor;
  final Color activeTextColor;
  final Color textFieldTextColor;
  final bool isWritable;
  final bool isReadOnly;
  Function(String val)? onChange;
  final bool isCap;

  CustomTextField({
    required this.labelText,
    this.isCap = false,
    this.icon,
    super.key,
    this.maxLines = 1,
    required this.controller,
    this.onChange,
    this.hintText,
    this.tapOn,
    this.isNum = false,
    this.maxLength = 50,
    this.isPassword = false,
    this.autofillHints,
    required this.node,
    this.nextNode,
    this.onTap,
    this.backgroundColor = AppColors.textFieldBackgroundColor,
    this.borderActiveColor = Colors.transparent,
    this.textColor = AppColors.textPrimary,
    this.activeTextColor = AppColors.textPrimary,
    this.textFieldTextColor = AppColors.textPrimary,
    this.isWritable = true,
    this.isReadOnly = false,
    this.borderRadius = 0,
  });

  String? hintText;
  Function()? tapOn;
  final bool isNum;
  final VoidCallback? onTap;
  int maxLength;
  bool isPassword;
  final Iterable<String>? autofillHints;
  final double borderRadius;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool isHide = true;

  @override
  Widget build(BuildContext context) {
    // Logic for dynamic multi-line support
    final bool isMultiLine = widget.maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          readOnly: widget.isReadOnly,
          onTap: widget.onTap,

          // If multi-line, we set maxLines to null (infinite growth)
          // and minLines to your provided value (starting height).
          maxLines: isMultiLine ? null : 1,
          minLines: isMultiLine ? widget.maxLines : 1,

          textCapitalization: widget.isCap
              ? TextCapitalization.characters
              : TextCapitalization.none,
          onChanged: (val) {
            if (widget.onChange != null) {
              widget.onChange!(val);
            }
          },

          // Disable hard length limit for multi-line notes if preferred
          maxLength: isMultiLine ? null : widget.maxLength,

          keyboardType: widget.isNum
              ? const TextInputType.numberWithOptions(decimal: true)
              : (isMultiLine ? TextInputType.multiline : TextInputType.text),

          controller: widget.controller,
          obscureText: widget.isPassword ? isHide : false,
          autofillHints: widget.autofillHints,
          focusNode: widget.node,

          // Action is "newline" for multi-line, otherwise "next" or "done"
          textInputAction: isMultiLine
              ? TextInputAction.newline
              : (widget.nextNode == null ? TextInputAction.done : TextInputAction.next),

          onSubmitted: (value) {
            if (!isMultiLine && widget.nextNode != null) {
              widget.node.unfocus();
              FocusScope.of(context).requestFocus(widget.nextNode);
            }
          },
          enabled: widget.isWritable,
          style: TextStyle(color: widget.textFieldTextColor, fontSize: 18),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: widget.isPassword
                ? IconButton(
              onPressed: () {
                setState(() {
                  isHide = !isHide;
                });
              },
              icon: Icon(
                isHide ? Icons.visibility : Icons.visibility_off,
                color: AppColors.greyColor,
              ),
            )
                : widget.icon != null
                ? Icon(widget.icon, color: AppColors.greyColor)
                : null,
            filled: true,
            fillColor: widget.backgroundColor,
            hintText: widget.hintText,
            counterText: '',
            labelStyle: const TextStyle(color: AppColors.greyColor),
            hintStyle: const TextStyle(color: AppColors.greyColor, fontSize: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
              borderSide: const BorderSide(color: Colors.transparent, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
              borderSide: BorderSide(color: widget.borderActiveColor, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}