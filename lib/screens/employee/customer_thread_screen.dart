import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/models/customer.dart';
import 'package:call_companion/models/call.dart';
import 'package:call_companion/providers/call_provider.dart';
import 'package:call_companion/providers/customer_provider.dart';
import 'package:call_companion/widgets/call_tile.dart';
import 'package:call_companion/screens/chat/ai_chat_screen.dart';
import 'package:call_companion/screens/employee/call_detail_screen.dart';
import 'package:call_companion/theme.dart';

class CustomerThreadScreen extends StatefulWidget {
  final Customer customer;

  const CustomerThreadScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerThreadScreen> createState() => _CustomerThreadScreenState();
}

class _CustomerThreadScreenState extends State<CustomerThreadScreen> {
  List<Call> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() => _isLoading = true);
    
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final calls = await callProvider.getCallsByCustomer(widget.customer.id);
    
    setState(() {
      _calls = calls;
      _isLoading = false;
    });
  }

  void _showEditCustomerDialog() {
    final nameController = TextEditingController(text: widget.customer.name);
    final aliasController = TextEditingController(text: widget.customer.alias);
    final companyController = TextEditingController(text: widget.customer.company);
    final emailController = TextEditingController(text: widget.customer.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(
                  labelText: 'Alias/Nickname',
                  hintText: 'e.g., ABC Corp Contact',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
              
              final success = await customerProvider.updateCustomerInfo(
                widget.customer.id,
                alias: aliasController.text.trim().isEmpty ? null : aliasController.text.trim(),
                name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                company: companyController.text.trim().isEmpty ? null : companyController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
              );

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer updated successfully')),
                  );
                  setState(() {}); // Refresh to show updated data
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update customer'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
              widget.customer.phoneNumber,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditCustomerDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AIChatScreen(customer: widget.customer),
            ),
          );
        },
        child: const Icon(Icons.chat_bubble),
        tooltip: 'Chat with AI about this customer',
      ),
      body: Column(
        children: [
          // AI Chat button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIChatScreen(customer: widget.customer),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Chat with AI about this customer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          // Customer info card
          if (widget.customer.company != null || widget.customer.email != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
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
                  if (widget.customer.company != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.customer.company!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (widget.customer.email != null) const SizedBox(height: 8),
                  ],
                  if (widget.customer.email != null)
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.customer.email!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // Calls section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _calls.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.call_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No calls yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start recording calls with this customer to see them here',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Call History (${_calls.length})',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
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
          ),
        ],
      ),
    );
  }
}