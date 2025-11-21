import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MedsourcesScreen extends StatelessWidget {
  const MedsourcesScreen({super.key});

  static final List<_MedResource> _resources = [
    _MedResource(
      title: 'National Center for PTSD',
      url: 'https://www.ptsd.va.gov/',
      description:
          'Comprehensive resource for PTSD information, research, and treatment options.',
    ),
    _MedResource(
      title: 'Anxiety and Depression Association of America (ADAA)',
      url: 'https://adaa.org/',
      description:
          'Resources and support for anxiety, depression, and PTSD, including self-help tools.',
    ),
    _MedResource(
      title:
          'Substance Abuse and Mental Health Services Administration (SAMHSA)',
      url: 'https://www.samhsa.gov/',
      description:
          'Information on mental health services, treatment locators, and support for individuals with PTSD.',
    ),
    _MedResource(
      title: 'National Alliance on Mental Illness (NAMI)',
      url: 'https://www.nami.org/',
      description:
          'Education, support groups, and advocacy for those affected by mental illness, including PTSD.',
    ),
  ];

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open link: ${uri.host}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Recommended Medical Resources for PTSD Relief:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _resources.length; i++)
            _buildCard(context, i + 1, _resources[i]),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, int index, _MedResource resource) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLink(context, resource.url),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      index.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      resource.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open website',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _openLink(context, resource.url),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                resource.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openLink(context, resource.url),
                  icon: const Icon(Icons.link),
                  label: Text(resource.url),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedResource {
  final String title;
  final String url;
  final String description;
  const _MedResource({
    required this.title,
    required this.url,
    required this.description,
  });
}
