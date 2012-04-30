#
#
# This class can be used to perform
# an openstack all-in-one installation.
#
class openstack::all(
  # passing in the public ipaddress is required
  $public_address,
  # middleware credentials
  $mysql_root_password  = 'sql_pass',
  $rabbit_password      = 'rabbit_pw',
  $rabbit_user          = 'nova',
  # opestack credentials
  $admin_email          = 'someuser@some_fake_email_address.foo',
  $admin_user_password  = 'ChangeMe',
  $keystone_db_password = 'keystone_pass',
  $keystone_admin_token = 'keystone_admin_token',
  $nova_db_password     = 'nova_pass',
  $nova_user_password   = 'nova_pass',
  $glance_db_password   = 'glance_pass',
  $glance_user_password = 'glance_pass',
  # config
  $verbose              = true,
  $purge_nova_config    = true,
) {


  #
  # indicates that all nova config entries that we did
  # not specifify in Puppet should be purged from file
  #
  if ($purge_nova_config) {
    resources { 'nova_config':
      purge => true,
    }
  }

  # set up mysql server
  class { 'mysql::server':
    config_hash => {
      # the priv grant fails on precise if I set a root password
      # 'root_password' => $mysql_root_password,
      'bind_address'  => '127.0.0.1'
    }
  }

  ####### KEYSTONE ###########

  # set up keystone database
  class { 'keystone::db::mysql':
    password => $keystone_db_password,
  }
  # set up the keystone config for mysql
  class { 'keystone::config::mysql':
    password => $keystone_db_password,
  }
  # set up keystone
  class { 'keystone':
    admin_token  => $keystone_admin_token,
    bind_host    => '127.0.0.1',
    log_verbose  => $verbose,
    log_debug    => $verbose,
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

  # set up keystone user, endpoint, service
  class { 'glance::keystone::auth':
    password => $glance_user_password,
  }

  # creat glance db/user/grants
  class { 'glance::db::mysql':
    host     => '127.0.0.1',
    password => $glance_db_password,
  }

  # configure glance api
  class { 'glance::api':
    log_verbose       => $verbose,
    log_debug         => $verbose,
    auth_type         => 'keystone',
    auth_host         => '127.0.0.1',
    auth_port         => '35357',
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $glance_user_password,
  }

  # configure glance to store images to disk
  class { 'glance::backend::file': }

  class { 'glance::registry':
    log_verbose       => $verbose,
    log_debug         => $verbose,
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

  class { 'nova::db::mysql':
    password => $nova_db_password,
    host     => 'localhost',
  }

  class { 'nova':
    sql_connection     => "mysql://nova:${nova_db_password}@localhost/nova",
    rabbit_userid      => $rabbit_user,
    rabbit_password    => $rabbit_password,
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => '127.0.0.1:9292',
    network_manager    => 'nova.network.manager.FlatDHCPManager',
  }

  class { 'nova::api':
    enabled        => true,
    admin_password => $nova_user_password,
  }

  class { 'nova::scheduler':
    enabled => true
  }

  class { 'nova::network':
    enabled => true
  }

  nova::manage::network { "nova-vm-net":
    network       => '11.0.0.0/24',
    available_ips => 128,
  }

  nova::manage::floating { "nova-vm-floating":
    network       => '10.128.0.0/24',
  }

  class { 'nova::objectstore':
    enabled => true
  }

  class { 'nova::volume':
    enabled => true
  }

  class { 'nova::cert':
    enabled => true
  }

  class { 'nova::consoleauth':
    enabled => true
  }

  class { 'nova::vncproxy':
    host => $public_hostname,
  }

  class { 'nova::compute':
    enabled                       => true,
    vnc_enabled                   => true,
    vncserver_proxyclient_address => '127.0.0.1',
    vncproxy_host                 => $public_address,
  }

  class { 'nova::compute::libvirt':
    libvirt_type     => 'qemu',
    vncserver_listen => '127.0.0.1',
  }

  nova::network::bridge { 'br100':
    ip      => '11.0.0.1',
    netmask => '255.255.255.0',
  }

  ######## Horizon ########

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  class { 'horizon': }

  ######## End Horizon #####

}
