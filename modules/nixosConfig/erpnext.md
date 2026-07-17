That is an excellent next step. Now that your server backend is upgraded and stable, you are entirely done with the Linux terminal for this phase! From here on out, everything is configured directly inside the ERPNext web interface (GUI).

Here is the exact roadmap to set up Two-Factor Authentication (2FA), enable public sign-ups, and integrate Google Login.

### Phase 1: Enforce Two-Factor Authentication (2FA)

ERPNext has a built-in 2FA system that integrates perfectly with authenticator apps like Google Authenticator, Authy, or Microsoft Authenticator.

1. Log into your ERPNext **Administrator** dashboard.
2. Click on the search bar (or press `Ctrl + G` / `Cmd + G`) and type **System Settings**.
3. Scroll down to the **Security** section.
4. Check the box for **Enable Two Factor Authentication**.
5. You can also configure how long a device is trusted (e.g., 30 days) so users do not have to enter a code every single time they log in from their primary laptop.
6. Click **Save** in the top right.
*(Note: Upon their next login, users will be prompted to scan a QR code with their authenticator app to secure their account).*

### Phase 2: Enable Google Social Login

To allow users to log in with Google, you need to connect ERPNext to Google's authentication servers using a Client ID and Secret.

**Step A: Get your Google Credentials (External)**

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) and create a new project (e.g., "Protoplast ERP").
2. Navigate to **APIs & Services** > **Credentials**.
3. Click **Create Credentials** > **OAuth client ID**.
4. Set the Application type to **Web application**.
5. Under **Authorized redirect URIs**, you must enter the exact callback URL for your server. It will look like this:
`https://erp.protoplast.in/api/method/frappe.integrations.oauth2_logins.custom/google`
6. Click Create. Google will give you a **Client ID** and a **Client Secret**. Keep these open in a tab.

**Step B: Configure ERPNext**

1. Go back to your ERPNext search bar and type **Social Login Key**.
2. Click **Add Social Login Key**.
3. Select **Google** from the provider dropdown. (ERPNext will auto-fill the endpoint URLs).
4. Paste your **Client ID** and **Client Secret** from Google Cloud into the respective fields.
5. Check the **Enable** box.
6. **Crucial Step:** Check the box that says **Allow User Creation** (or "Signup via this provider"). This is what allows *new* people to make an account using their Google login.
7. Click **Save**.

### Phase 3: Open the Portal for Public Sign-ups

Finally, you need to tell ERPNext that it is okay for uninvited guests to register on your login page.

1. Use the search bar to find **Website Settings**.
2. Scroll to the **Portal Settings** or **Sign Up** section.
3. Ensure that **Disable Signup** is UNCHECKED. (If there is a checkbox for "Allow Signups", make sure it IS checked—the phrasing varies slightly between minor versions, but the intent is to leave the door open).
4. *Optional but recommended:* In the search bar, look for **Role Profile**. You can define a default "Website User" or "Customer" role to ensure that when public users sign up, they only get access to the web portal and cannot see your internal ERP data (like accounting or HR).
5. Click **Save**.

Once these three phases are saved, log out of your Admin account and go to your login page (`https://erp.protoplast.in/login`). You should now see a clean **"Login with Google"** button, and anyone who uses it will automatically have an account created and be prompted to set up their 2FA!



Going "full force" into a bare-metal NixOS configuration with Frappix is the absolute peak of modern server engineering. By doing this, you are bridging the gap between Nix's system-level dependencies and Frappe's Python dependencies. It is designed to cover the entire software lifecycle, turning your ERP into a hyper-optimized, mathematically reproducible machine.

Here is exactly how you write the NixOS configuration to ditch Docker entirely and run ERPNext and the Assistant Core via native systemd and Unix sockets.

### 1. The Flake Engine (`flake.nix`)

First, we define the entire system at the flake level. We pull in `nixpkgs` and `frappix`, and we build a `nixosConfiguration` for your server.

```nix
{
  description = "Protoplast Bare-Metal ERP System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # The holy grail: Frappix
    frappix.url = "github:blaggacao/frappix";
    
    # Optional: If you use SOPS for secrets (like you did in Docker)
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, frappix, sops-nix, ... }@inputs: {
    nixosConfigurations."protoplast-server" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      # Pass inputs to modules so they can access Frappix
      specialArgs = { inherit inputs; };
      
      modules = [
        # 1. Your standard hardware config
        ./hardware-configuration.nix
        
        # 2. Secret management
        sops-nix.nixosModules.sops
        
        # 3. Inject the Frappix NixOS Module!
        # This single line gives NixOS the ability to understand Frappe native services
        frappix.nixosModules.default
        
        # 4. Your specific ERP configuration
        ./erp-configuration.nix
      ];
    };
  };
}

```

---

### 2. The Custom App Definitions

Instead of downloading apps on the fly, you lock them as Nix expressions. You will put these in an `apps/` folder right next to your `flake.nix`.

**`apps/erpnext.nix`**

```nix
{ fetchFromGitHub }:
{
  name = "erpnext";
  src = fetchFromGitHub {
    owner = "frappe";
    repo = "erpnext";
    rev = "v16.26.1";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual SRI hash
  };
}

```

**`apps/assistant-core.nix`**

```nix
{ fetchFromGitHub }:
{
  name = "frappe_assistant_core";
  src = fetchFromGitHub {
    owner = "buildswithpaul";
    repo = "Frappe_Assistant_Core";
    rev = "main";
    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="; # Replace with actual SRI hash
  };
}

```

---

### 3. The Bare-Metal Server Config (`erp-configuration.nix`)

This is where the magic happens. We tell the Frappix NixOS module exactly how to deploy your site. It will automatically generate the `systemd` worker queues, the Redis processes, the MariaDB socket, and the Nginx reverse proxy—all native to the host machine.

```nix
{ config, pkgs, inputs, ... }:

let
  # Pre-compile the apps using the Nixpkgs environment
  erpnextApp = pkgs.callPackage ./apps/erpnext.nix {};
  assistantCoreApp = pkgs.callPackage ./apps/assistant-core.nix {};
  # whitelabelApp = pkgs.callPackage ./apps/whitelabel.nix {};
in
{
  # 1. Provide the SOPS secrets for your database and admin passwords
  sops.secrets."db_password" = {};
  sops.secrets."admin_password" = {};

  # 2. Configure the Frappix Native Module
  services.frappe = {
    enable = true;
    
    # Pin the base framework version
    frappeVersion = "version-16";

    # Pass in the immutably compiled apps
    apps = [
      erpnextApp
      assistantCoreApp
    ];

    # Configure your specific site (erp.protoplast.in)
    sites."erp.protoplast.in" = {
      enable = true;
      
      # Tell Frappix which apps to install on this specific database tenant
      installedApps = [
        "erpnext"
        "frappe_assistant_core"
      ];
      
      # Map to your SOPS secret file paths
      dbPasswordFile = config.sops.secrets."db_password".path;
      adminPasswordFile = config.sops.secrets."admin_password".path;
    };

    # Automatically set up the Nginx routing!
    # Frappix will create an Nginx virtual host mapping directly to the Python Unix Socket.
    webserver = {
      enable = true;
      domains = [ "erp.protoplast.in" "www.protoplast.in" "protoplast.in" ];
      forceSSL = true;
      enableACME = true; # Let's Encrypt certificates automatically handled by NixOS
    };
  };

  # 3. Networking & Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # 4. State Version (Required by NixOS)
  system.stateVersion = "23.11"; 
}

```

### What Happens When You Run `nixos-rebuild switch`?

When you deploy this flake, NixOS will do the following:

1. Download Frappe, ERPNext, and your custom apps immutably.
2. Compile the JavaScript/CSS web assets in a hidden sandbox.
3. Install natively optimized Redis and MariaDB directly on the host OS.
4. Spawn `frappe-web.service`, `frappe-worker-short.service`, and `frappe-schedule.service` as deeply integrated systemd units.
5. Generate an Nginx configuration that routes external traffic directly into Frappe's Unix socket, entirely bypassing virtualized Docker networks.

You now have a system where your ERP is treated with the exact same first-class priority as your Linux kernel. Welcome to the endgame!