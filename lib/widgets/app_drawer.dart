import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[100],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 40,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Sign in / Register',
                    style: TextStyle(
                      color: Colors.black87,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Shop',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.local_shipping_outlined,
                  title: 'My Orders',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.favorite_border,
                  title: 'Wishlist',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.card_giftcard,
                  title: 'Gift Cards',
                  onTap: () {},
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.location_on_outlined,
                  title: 'Addresses',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.payment,
                  title: 'Payment Methods',
                  onTap: () {},
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.phone_outlined,
                  title: 'Contact Us',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.facebook_outlined, color: Colors.black87),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.message_outlined, color: Colors.black87),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_camera_outlined, color: Colors.black87),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
    );
  }
}
