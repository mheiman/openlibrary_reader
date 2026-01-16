import 'package:flutter/material.dart';

import '../../../../core/widgets/dialog_header.dart';

/// Generic sort option model
class GenericSortOption<T> {
  bool isSelected;
  final T sortValue;
  final String description;

  GenericSortOption({
    required this.isSelected,
    required this.sortValue,
    required this.description,
  });
}

/// Generic dialog for sorting
class GenericSortDialog<T> extends StatefulWidget {
  final String title;
  final List<GenericSortOption<T>> sortOptions;
  final bool initialAscending;
  final Function(T sortValue, bool ascending) onSortChanged;

  const GenericSortDialog({
    super.key,
    required this.title,
    required this.sortOptions,
    required this.initialAscending,
    required this.onSortChanged,
  });

  @override
  State<GenericSortDialog<T>> createState() => _GenericSortDialogState<T>();
}

class _GenericSortDialogState<T> extends State<GenericSortDialog<T>> {
  late List<GenericSortOption<T>> sortOptions;
  late bool ascending;

  @override
  void initState() {
    super.initState();
    ascending = widget.initialAscending;
    sortOptions = List.from(widget.sortOptions); // Create a copy
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 275.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogHeader(title: widget.title),
            ListView.builder(
              shrinkWrap: true,
              itemCount: sortOptions.length,
              itemBuilder: (context, index) {
                return InkWell(
                  splashColor: Colors.blueAccent,
                  onTap: () {
                    setState(() {
                      // If tapping the currently selected option, toggle direction
                      if (sortOptions[index].isSelected) {
                        ascending = !ascending;
                      } else {
                        // Clear all selections and select this one
                        for (var option in sortOptions) {
                          option.isSelected = false;
                        }
                        sortOptions[index].isSelected = true;
                        // Default to ascending for new selection
                        ascending = true;
                      }

                      // Notify parent
                      widget.onSortChanged(
                        sortOptions[index].sortValue,
                        ascending,
                      );
                    });
                  },
                  child: _GenericSortOptionItem<T>(
                    option: sortOptions[index],
                    ascending: ascending,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual sort option item
class _GenericSortOptionItem<T> extends StatelessWidget {
  final GenericSortOption<T> option;
  final bool ascending;

  const _GenericSortOptionItem({
    required this.option,
    required this.ascending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(15.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Sort direction indicator
          Container(
            height: 50.0,
            width: 50.0,
            margin: const EdgeInsets.only(right: 10.0),
            decoration: BoxDecoration(
              color: option.isSelected ? Colors.blueAccent : Colors.transparent,
              border: Border.all(
                width: 1.0,
                color: option.isSelected ? Colors.blueAccent : Colors.grey,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(2.0)),
            ),
            child: Center(
              child: Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                color: option.isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),

          // Option description
          Expanded(
            child: Text(
              option.description,
              softWrap: true,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ],
      ),
    );
  }
}