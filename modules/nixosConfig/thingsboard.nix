{
  flake.nixosModules.protoplast_tb = { config, pkgs, ... }:
  {
    sops.templates."tb-db.env".content = ''
      SPRING_DATASOURCE_PASSWORD=${config.sops.placeholder.tb_db_password}
    '';

    sops.templates."set-tb-password.sql" = {
      content = "ALTER ROLE thingsboard WITH PASSWORD '${config.sops.placeholder.tb_db_password}';";
      owner = "postgres";
    };

    services.postgresql = {
      ensureDatabases = [ "thingsboard" ];
      ensureUsers = [{
        name = "thingsboard";
        ensureDBOwnership = true;
      }];
    };

    systemd.services.postgresql.postStart = pkgs.lib.mkAfter ''
      $PSQL -f ${config.sops.templates."set-tb-password.sql".path}
    '';
    
    virtualisation.oci-containers = {
      backend = "docker";
      
      containers = {
        "protoplast_tb_init" = {
          image = "protoplaststudio/tb-node:latest";
          cmd = [ "install-db.sh" "--loadDemo=false" ];
          environment = {
            "DATABASE_ENTITIES_TYPE" = "sql";
            "SPRING_DATASOURCE_URL" = "jdbc:postgresql://172.17.0.1:5432/thingsboard";
            "SPRING_DATASOURCE_USERNAME" = "thingsboard";
          };
          environmentFiles = [ config.sops.templates."tb-db.env".path ];
        };
        "protoplast_tb_postgres" = {
          image = "protoplaststudio/tb-node:latest"; 
          
          ports = [
            "127.0.0.1:9090:9090" 
          ];
  
          environment = {
            # --- DATABASE CONNECTION: HOST-MANAGED ---
            "DATABASE_ENTITIES_TYPE" = "sql";
            "SPRING_DATASOURCE_URL" = "jdbc:postgresql://172.17.0.1:5432/thingsboard";
            "SPRING_DATASOURCE_USERNAME" = "thingsboard";
            # Add your password here if you set one in services.postgresql.authentication
            "SQL_TTL_TELEMETRY_ENABLED" = "true";
            "SQL_TTL_TELEMETRY_TTL" = "2592000";   # 30 days
            "SQL_TTL_ERROR_EVENTS_TTL" = "604800";   # 7 days
            "SQL_TTL_DEBUG_EVENTS_TTL" = "604800";   # 7 days
            "SQL_TTL_AUDIT_LOGS_TTL" = "2592000";    # 30 days
          };
          environmentFiles = [ config.sops.templates."tb-db.env".path ];
        };
      };
    };
    systemd.services."docker-protoplast_tb_postgres" = {
      after = [ "docker-protoplast_tb_init.service" ];
      wants = [ "docker-protoplast_tb_init.service" ];
    };
  };
}