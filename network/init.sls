
{% set global = pillar.get('netconf') %}

{% set files = [] %}
{% set global_mtu = global.mtu is defined and global.mtu or '1500' %}
{% set global_dhcp = global.dhcp is defined and global.dhcp or 'no' %}
{% set global_send_hostname = global.send_hostname is defined and global.send_hostname or 'yes' %}

{% for iface_name, device in global.devices.items() %}

{% set dev_mtu = device.mtu is defined and device.mtu or global_mtu %}
{% set dev_dhcp = device.dhcp is defined and device.dhcp or global_dhcp %}
{% set dev_send_hostname = device.send_hostname is defined and device.send_hostname or global_send_hostname %}

{% if device.vlans is defined %}

# Create a list of vlans
{% set vlans = [] %}
{% for key,value in device.vlans.items() %}
{% do vlans.append(key) %}
{% endfor %}

# Network config for the physical devices
{% do files.append("/etc/systemd/network/" + iface_name + ".network") %}
/etc/systemd/network/{{ iface_name }}.network:
  file.managed:
    - name:
    - source: salt://network/files/trunk.network
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        iface_name: "{{ iface_name }}"
        vlans: {{ vlans }}
        mtu: {{ dev_mtu }}

{% for vlan_name, vlan in device.vlans.items() %}

{% set vlan_mtu = vlan.mtu is defined and vlan.mtu or dev_mtu %}
{% set vlan_dhcp = vlan.dhcp is defined and vlan.dhcp or dev_dhcp %}
{% set vlan_send_hostname = vlan.send_hostname is defined and vlan.send_hostname or dev_send_hostname %}

# Virtual network device for a vlan
{% do files.append("/etc/systemd/network/" + vlan_name + ".netdev") %}
/etc/systemd/network/{{ vlan_name }}.netdev:
  file.managed:
    - source: salt://network/files/vlan.netdev
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        vlan_name: "{{ vlan_name }}"
        vlan_id: {{ vlan.id }}

{% if vlan.bridge is defined %}

# Network config for vlan device as a bridge
{% do files.append("/etc/systemd/network/" + vlan_name + ".network") %}
/etc/systemd/network/{{ vlan_name }}.network:
   file.managed:
    - source: salt://network/files/bridge.network
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        iface_name: "{{ vlan_name }}"
        bridge_name: "{{ vlan.bridge }}"
        mtu: {{ dev_mtu }}

# Virtual network device for bridge
{% do files.append("/etc/systemd/network/" + vlan.bridge + ".netdev") %}
/etc/systemd/network/{{ vlan.bridge }}.netdev:
   file.managed:
    - source: salt://network/files/bridge.netdev
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        bridge_name: "{{ vlan.bridge }}"

# Network config for bridge device
{% do files.append("/etc/systemd/network/" + vlan.bridge + ".network") %}
/etc/systemd/network/{{ vlan.bridge }}.network:
   file.managed:
    - source: salt://network/files/standard.network
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        iface_name: "{{ vlan.bridge }}"
        dhcp: "{{ vlan_dhcp }}"
        mtu: {{ vlan_mtu }}
        {% if vlan.dns is defined %}
        dns: "{{ vlan.dns }}"
        {% endif %}
        {% if vlan.address is defined %}
        address: "{{ vlan.address }}"
        {% endif %}
        {% if vlan.gateway is defined %}
        gateway: "{{ vlan.gateway }}"
        {% endif %}
        send_hostname: "{{ vlan_send_hostname }}"

{% else %}

# Network config for vlan device as a non-bridge device
{% do files.append("/etc/systemd/network/" + vlan_name + ".network") %}
/etc/systemd/network/{{ vlan_name }}.network:
   file.managed:
    - source: salt://network/files/standard.network
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        iface_name: "{{ vlan_name }}"
        dhcp: "{{ vlan_dhcp }}"
        mtu: {{ vlan_mtu }}
        {% if vlan.dns is defined %}
        dns: "{{ vlan.dns }}"
        {% endif %}
        {% if vlan.address is defined %}
        address: "{{ vlan.address }}"
        {% endif %}
        {% if vlan.gateway is defined %}
        gateway: "{{ vlan.gateway }}"
        {% endif %}
        send_hostname: "{{ vlan_send_hostname }}"

{% endif %}
{% endfor %}

{% else %}  # if device.vlans is not defined

{% do files.append("/etc/systemd/network/" + iface_name + ".network") %}
/etc/systemd/network/{{ iface_name }}.network:
   file.managed:
    - source: salt://network/files/standard.network
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
        iface_name: "{{ iface_name }}"
        dhcp: "{{ dev_dhcp }}"
        mtu: {{ dev_mtu }}
        {% if device.dns is defined %}
        dns: "{{ device.dns }}"
        {% endif %}
        {% if device.address is defined %}
        address: "{{ device.address }}"
        {% endif %}
        {% if device.gateway is defined %}
        gateway: "{{ device.gateway }}"
        {% endif %}
        send_hostname: "{{ dev_send_hostname }}"

{% endif %}
{% endfor %}

systemd-networkd:
  service.running:
    - enable: True
    - watch:
{% for file in files %}
      - file: {{ file }}
{% endfor %}

