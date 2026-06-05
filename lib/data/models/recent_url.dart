/// Uma URL aberta recentemente, exibida na tela inicial.
class RecentUrl {
  const RecentUrl({required this.url, required this.lastOpened});

  final String url;
  final DateTime lastOpened;

  Map<String, dynamic> toJson() => {
        'url': url,
        'lastOpened': lastOpened.toIso8601String(),
      };

  factory RecentUrl.fromJson(Map<String, dynamic> json) => RecentUrl(
        url: json['url'] as String,
        lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
