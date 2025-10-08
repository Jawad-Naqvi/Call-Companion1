import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:call_companion/models/call.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/transcript.dart';
import 'package:call_companion/models/ai_summary.dart';
import 'package:call_companion/services/transcription_service.dart';
import 'package:call_companion/services/ai_service.dart';
import 'package:call_companion/theme.dart';
import 'package:intl/intl.dart';

class CallDetailScreen extends StatefulWidget {
  final Call call;
  final Customer customer;

  const CallDetailScreen({
    super.key,
    required this.call,
    required this.customer,
  });

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TranscriptionService _transcriptionService = TranscriptionService();
  final AIService _aiService = AIService();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  Transcript? _transcript;
  bool _isLoadingTranscript = false;
  bool _isTranscribing = false;
  
  AISummary? _aiSummary;
  bool _isLoadingAISummary = false;
  bool _isGeneratingAISummary = false;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _loadTranscript();
    _loadAISummary();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  Future<void> _loadTranscript() async {
    setState(() => _isLoadingTranscript = true);
    
    try {
      final transcript = await _transcriptionService.getTranscriptByCallId(widget.call.id);
      setState(() {
        _transcript = transcript;
        _isLoadingTranscript = false;
      });
    } catch (e) {
      setState(() => _isLoadingTranscript = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transcript: $e')),
        );
      }
    }
  }

  Future<void> _loadAISummary() async {
    setState(() => _isLoadingAISummary = true);
    
    try {
      final summary = await _aiService.getAISummaryByCallId(widget.call.id);
      setState(() {
        _aiSummary = summary;
        _isLoadingAISummary = false;
      });
    } catch (e) {
      setState(() => _isLoadingAISummary = false);
    }
  }

  Future<void> _generateTranscript() async {
    if (widget.call.audioFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio file available')),
      );
      return;
    }

    // Show API key dialog
    final apiKey = await _showApiKeyDialog('Whisper API Key', 'Enter your OpenAI API key');
    if (apiKey == null || apiKey.isEmpty) return;

    setState(() => _isTranscribing = true);

    try {
      final transcript = await _transcriptionService.transcribeCall(
        widget.call,
        apiKey,
        provider: 'whisper',
      );

      if (transcript != null) {
        setState(() {
          _transcript = transcript;
          _isTranscribing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transcript generated successfully')),
          );
        }
      } else {
        throw Exception('Failed to generate transcript');
      }
    } catch (e) {
      setState(() => _isTranscribing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating transcript: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateAISummary() async {
    if (_transcript == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate transcript first')),
      );
      return;
    }

    // Show API key dialog
    final apiKey = await _showApiKeyDialog('Gemini API Key', 'Enter your Google Gemini API key');
    if (apiKey == null || apiKey.isEmpty) return;

    setState(() => _isGeneratingAISummary = true);

    try {
      final summary = await _aiService.generateCallSummary(_transcript!, apiKey: apiKey);

      if (summary != null) {
        setState(() {
          _aiSummary = summary;
          _isGeneratingAISummary = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI summary generated successfully')),
          );
        }
      } else {
        throw Exception('Failed to generate AI summary');
      }
    } catch (e) {
      setState(() => _isGeneratingAISummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating AI summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showApiKeyDialog(String title, String hint) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (widget.call.audioFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio file available')),
      );
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position == Duration.zero) {
        await _audioPlayer.play(UrlSource(widget.call.audioFileUrl!));
      } else {
        await _audioPlayer.resume();
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customer.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              DateFormat('MMM d, yyyy • HH:mm').format(widget.call.startTime),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio Player
            if (widget.call.audioFileUrl != null)
              _buildAudioPlayer(),

            // Transcript Section
            _buildTranscriptSection(),

            // AI Summary Section
            _buildAISummarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightCardSurface
            : DarkModeColors.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Call Recording',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
          
          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _formatDuration(_duration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Play/Pause button
          FilledButton.icon(
            onPressed: _togglePlayPause,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(_isPlaying ? 'Pause' : 'Play'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightCardSurface
            : DarkModeColors.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.transcribe,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Transcript',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingTranscript)
            const Center(child: CircularProgressIndicator())
          else if (_isTranscribing)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Generating transcript...'),
                ],
              ),
            )
          else if (_transcript != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _transcript!.fullText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.light
                          ? LightModeColors.lightSuccess
                          : DarkModeColors.darkSuccess,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Confidence: ${(_transcript!.confidence ?? 0.0 * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ],
            )
          else
            Center(
              child: Column(
                children: [
                  Text(
                    'No transcript available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generateTranscript,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Transcript'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAISummarySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightCardSurface
            : DarkModeColors.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'AI Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingAISummary)
            const Center(child: CircularProgressIndicator())
          else if (_isGeneratingAISummary)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Generating AI summary...'),
                ],
              ),
            )
          else if (_aiSummary != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _aiSummary!.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                
                const SizedBox(height: 16),
                
                // Sentiment
                Row(
                  children: [
                    Text(
                      'Sentiment: ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSentimentColor(_aiSummary!.sentiment),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _aiSummary!.sentiment.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (_aiSummary!.keyHighlights.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Key Highlights',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._aiSummary!.keyHighlights.map((highlight) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                highlight,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                
                if (_aiSummary!.nextSteps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Next Steps',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._aiSummary!.nextSteps.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                
                if (_aiSummary!.concerns.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Concerns',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._aiSummary!.concerns.map((concern) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? LightModeColors.lightWarning
                                  : DarkModeColors.darkWarning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                concern,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            )
          else
            Center(
              child: Column(
                children: [
                  Text(
                    'No AI summary available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _transcript != null ? _generateAISummary : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate AI Summary'),
                  ),
                  if (_transcript == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Generate transcript first',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getSentimentColor(SentimentType sentiment) {
    switch (sentiment) {
      case SentimentType.positive:
        return Theme.of(context).brightness == Brightness.light
            ? LightModeColors.lightSuccess
            : DarkModeColors.darkSuccess;
      case SentimentType.negative:
        return Colors.red;
      case SentimentType.neutral:
        return Colors.grey;
    }
  }
}
