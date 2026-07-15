void main() { List<dynamic> w = [{'title': 'A'}]; var r = w.firstWhere((x) => x['title'] == 'B', orElse: () => null); print(r); }
