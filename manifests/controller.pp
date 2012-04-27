#
# This can be used to build out the simplest openstack controller
#
#
#
#

class openstack::controller(
  # my address
  $public_address,
  $internal_address,
  # connection information
  $mysql_root_password  = 'sql_pass',
  $admin_email          = 'dan@puppetlabs.com',
  $admin_user_password  = 'ChangeMe',
  $rabbit_password      = 'rabbit_pw',
  $rabbit_user          = 'nova',
  $nova_db_password     = 'nova_pass',
  $nova_user_password   = 'nova_pass',
  $keystone_db_password = 'keystone_pass',
  $keystone_admin_token = 'keystone_admin_token',
  $glance_db_password   = 'glance_pass',
  $glance_user_password = 'glance_pass'
) {

  $glance_api_servers = "${internal_address}:9292"
  $nova_db = "mysql://nova:${nova_db_password}@${internal_address}/nova"

  # export all of the things that will be needed by the clients
  @@nova_config { 'rabbit_host': value => $internal_address }
  Nova_config <| title == 'rabbit_host' |>
  @@nova_config { 'sql_connection': value => $nova_db }
  Nova_config <| title == 'sql_connection' |>
  @@nova_config { 'glance_api_servers': value => $glance_api_servers }
  Nova_config <| title == 'glance_api_servers' |>
  @@nova_config { 'novncproxy_base_url': value => "http://${public_address}:6080/vnc_auto.html" }

  # set up mysql server
  class { 'mysql::server':
    config_hash => {
      # the priv grant fails on precise if I set a root password
      # 'root_password' => $mysql_root_password,
      'bind_address'  => '0.0.0.0'
    }
  }
  # set up all openstack databases, users, grants
  class { 'keystone::db::mysql':
    password => $keystone_db_password,
  }
  class { 'glance::db::mysql':
    host     => '127.0.0.1',
    password => $glance_db_password,
  }
  class { 'nova::db::mysql':
    password      => $nova_db_password,
    host          => $internal_address,
    allowed_hosts => '%',
  }

  ####### KEYSTONE ###########

  # set up keystone database
  # set up the keystone config for mysql
  class { 'keystone::config::mysql':
    password => $keystone_db_password,
  }
  # set up keystone
  class { 'keystone':
    admin_token  => $keystone_admin_token,
    bind_host    => '127.0.0.1',
    log_verbose  => true,
    log_debug    => true,
    catalog_type => 'sql',
  }
  # set up keystone admin users
  class { 'keystone::roles::admin':
    email    => $admin_email,
    password => $admin_user_password,
  }
  # set up the keystone service and endpoint
  class { 'keystone::endpoint': }

  ######## END KEYSTONE ##########

  ######## BEGIN GLANCE ##########

  class { 'glance::keystone::auth':
    password => $glance_user_password,
  }

  class { 'glance::api':
    log_verbose       => 'True',
    log_debug         => 'True',
    auth_type         => 'keystone',
    auth_host         => '127.0.0.1',
    auth_port         => '35357',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $glance_user_password,
  }
  class { 'glance::backend::file': }

  class { 'glance::registry':
    log_verbose       => 'True',
    log_debug         => 'True',
    auth_type         => 'keystone',
    auth_host         => '127.0.0.1',
    auth_port         => '35357',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $glance_user_password,
    sql_connection    => "mysql://glance:${glance_db_password}@127.0.0.1/glance",
  }


  ######## END GLANCE ###########

  ######## BEGIN NOVA ###########

  class { 'nova::keystone::auth':
    password => $nova_user_password,
  }

  class { 'nova::rabbitmq':
    userid   => $rabbit_user,
    password => $rabbit_password,
  }

  class { 'nova':
    sql_connection     => false,
    # this is false b/c we are exporting
    rabbit_host        => false,
    rabbit_userid      => $rabbit_user,
    rabbit_password    => $rabbit_password,
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => false,
    network_manager    => 'nova.network.manager.FlatDHCPManager',
  }

  class { 'nova::api':
    enabled           => true,
    admin_tenant_name => 'openstack',
    admin_user        => 'admin',
    admin_password    => $admin_user_password,
  }

  class { 'nova::scheduler':
    enabled => true,
  }

  class { 'nova::network':
    enabled => true,
  }

  nova::manage::network { 'nova-vm-net':
    network       => '11.0.0.0/24',
    available_ips => 128,
  }

  nova::manage::floating { 'nova-vm-floating':
    network       => '10.128.0.0/24',
  }

  class { 'nova::objectstore':
    enabled => true
  }

  class { 'nova::vncproxy':
    enabled => true,
  }

  ######## Horizon ########

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  class { 'horizon': }


  ######## End Horizon #####

}
