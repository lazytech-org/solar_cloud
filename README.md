# solar_cloud
ESP8266 firmware for solar panels control and monitoring

Solar Cloud is a complete solution to control thermal solar panels with an esp8266 board

## Hardware Setup

TODO

## Installation

Use a nodemcu firmware > 1.0 with these modules:

* bit
* CJSON
* crypto
* file
* GPIO
* HTTP
* I²C
* net
* node
* 1-Wire
* timer
* UART
* WiFi

you can use [The Nodemcu Cloud Build Service](https://nodemcu-build.com/) to build the firmware and [esptool](https://github.com/themadinventor/esptool) to flash it.

Just copy the lua files at the root of the flash with [Esplorer](https://github.com/4refr0nt/ESPlorer) or other tool and reset.
The lua files will be compiled at the first start.

To generate the web files, just execute make and copy the undescore prefixed files to the flash with Esplorer.

## Configuration

All the settings are located at lines 67 - 96 of the file init.lua, only the EmonCMS api key is mandatory:

    conf = {host = "http://emoncms.org", -- EmmonCMS host
          consign = 40,
          interval = 6,
          tstockpin = 3,
          apssid = "Solar_Cloud", -- ESSID in APmode
          tthermpin = 1,
          thybpin = 2,
          ads_sda = 4,
          ads_scl = 5,
          phot_pin = 1,
          phot_volts = 12,
          phot_amp = 10,
          dmpin = 7,
          srpumppin = 0,
          srevpin = 6,
          srrespin = 8,
          delta_t = 4,
          delay_min = 15,
          port = 80} -- default port in APmode
    write_conf("config.json", conf)
    end
    if file.open('secret.json', "r") then
        secret = cjson.decode(file.readline())
        file.close()
    else
        secret = {apikey = "YOUR EMON CMS API KEY HERE", -- EmonCMS api key
            appwd = "lazytech",     -- WiFi password
            admpwd = "password"}    -- admin password
        write_conf("secret.json", secret)
    end

## Usage

If the WiFi is not set or avalaible, the system will start in AP mode.

You have to connect to the ESSID "Solar_Cloud", the PSK password is "lazytech"

Once you are connected, point your browser to http://192.168.1.4, the admin page will show.

The default admin password is "password".

Once the Wifi configured, the system will reboot in station mode and send the data to your EmonCMS instance.

The admin page is still available at the IP obtained from your WiFi router, this address can be obtained via the emonCMS inputs ip1, ip2, ip3, ip4.



 

 
