const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}, ${h.toString().padLeft(2, '0')}:$m $ap';
}

String shortDay(DateTime d) => '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
