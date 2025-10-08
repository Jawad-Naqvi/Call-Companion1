import 'package:flutter/material.dart';
import 'package:call_companion/models/user.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/call.dart';
import 'package:call_companion/services/call_service.dart';
import 'package:call_companion/screens/employee/call_detail_screen.dart';
import 'package:call_companion/widgets/call_tile.dart';

class CustomerCallsScreen extends StatefulWidget {
  final Customer customer;
  final User employee;

  const CustomerCallsScreen({
    super.key,
    required this.customer,
    required this.employee,
  });

  @override
  State<CustomerCallsScreen> createState() => _CustomerCallsScreenState();
}

class _CustomerCallsScreenState extends State<CustomerCallsScreen> {
  final CallService _callService = CallService();
  List<Call> _calls = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final calls = await _callService.getCallsByCustomer(widget.customer.id);
      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load calls: $e';
        _isLoading = false;
      });
    }
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
              'Calls with ${widget.employee.name}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading calls',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadCalls,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _calls.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.call_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No calls yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No calls recorded with this customer',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'Call History (${_calls.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final call = _calls[index];
                                return CallTile(
                                  call: call,
                                  customer: widget.customer,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CallDetailScreen(
                                          call: call,
                                          customer: widget.customer,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: _calls.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
