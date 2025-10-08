import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/providers/recording_provider.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/services/customer_service.dart';

class CallRecordingScreen extends StatefulWidget {
  const CallRecordingScreen({super.key});

  @override
  State<CallRecordingScreen> createState() => _CallRecordingScreenState();
}

class _CallRecordingScreenState extends State<CallRecordingScreen> {
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _recentCustomers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentCustomers();
  }

  Future<void> _loadRecentCustomers() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final customers = await _customerService.getRecentCustomers(authProvider.user!.id);
      setState(() {
        _recentCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Recording'),
      ),
      body: Column(
        children: [
          // Global Recording Toggle
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Record All Calls',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All calls will be recorded automatically',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    Consumer<RecordingProvider>(
                      builder: (context, recordingProvider, _) {
                        return Switch(
                          value: recordingProvider.isRecordingEnabled,
                          onChanged: (value) {
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            recordingProvider.toggleRecording(authProvider.user!.id);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Implement customer search
              },
            ),
          ),

          // Recent Customers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recentCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _recentCustomers[index];
                      return _buildCustomerTile(customer);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            customer.displayName[0].toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(customer.displayName),
        subtitle: Text(customer.phoneNumber),
        trailing: IconButton(
          icon: const Icon(Icons.chat_outlined),
          onPressed: () {
            // Navigate to customer thread
          },
        ),
        onTap: () {
          // Navigate to customer details/thread
        },
      ),
    );
  }
}