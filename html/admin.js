/*globals DataView, TextEncoder, WebSocket, alert, console, sha256*/
var sock = null;
var ellog = null;
var fails = 0;
var wsuri = null;
var admin = false;
var admin_closed = true;
var token = "";
var toSend = {};
var arRssi = [];
var aps = {};
var cryptoObj = null;
var node_ip = "";
var currAp = "";
var node_ip = "";

function minimum_field(obj, size) {
    "use strict";
    if (obj.value.length < size) {
        alert("key should be at least " + size + " char long");
    }
}

function log(m) {
    "use strict";
    ellog.innerHTML += m + '\n';
    ellog.scrollTop = ellog.scrollHeight;
}

function rssi_sort(a, b) {
    "use strict";
    return -(a - b);
}

function set_essid() {
    "use strict";
    log(this.value);
    var secure = (this.secure !== "0");
    currAp = this.value;
    document.getElementById("connectbtn").disabled = false;
    if (secure) {
        document.getElementById("wifikey").disabled = false;
        document.getElementById("wifikey").value = "";
    } else {
        document.getElementById("wifikey").disabled = true;
    }
}

function update_wifi_widget() {
    "use strict";
    var wifi_form = document.getElementById("wifi_settings"), r, k, ap, rssi, rssiVal, encrypt, encVal, inpt, lbl;
    wifi_form.style.display = "block";
    wifi_form.innerHTML = "";
    arRssi.sort(rssi_sort);
    for (r in arRssi) {
        if (arRssi.hasOwnProperty(r)) {
            for (k in aps) {
                if (aps.hasOwnProperty(k)) {
                    if (arRssi[r] === aps[k][0]) {
                        log(k + ": " + arRssi[r].toString());
                        ap = document.createElement("div");
	                    ap.id = "apdiv";
	                    rssi = document.createElement("div");
	                    rssiVal = -Math.floor(arRssi[r] / 31) * 32;
	                    rssi.className = "icon";
                        log(rssiVal);
	                    rssi.style.backgroundPosition = "0px " + rssiVal + "px";
	                    encrypt = document.createElement("div");
	                    encVal = "-64"; //assume wpa/wpa2
	                    if (aps[k][1] === "0") {encVal = "0"; } //open
	                    if (aps[k][1] === "1") { encVal = "-32"; } //wep
	                    encrypt.className = "icon";
	                    encrypt.style.backgroundPosition = "-32px " + encVal + "px";
	                    inpt = document.createElement("input");
	                    inpt.type = "radio";
	                    inpt.name = "essid";
	                    inpt.value = k;
                        inpt.secure = encVal;
                        inpt.onchange = set_essid;
	                    if (currAp === k) { inpt.checked = "1"; }
	                    inpt.id = "opt-" + ap.essid;
	                    lbl = document.createElement("label");
	                    lbl.htmlFor = "opt-" + k;
	                    lbl.textContent = k;
	                    ap.appendChild(inpt);
	                    ap.appendChild(rssi);
	                    ap.appendChild(encrypt);
	                    ap.appendChild(lbl);
                        wifi_form.appendChild(ap);
                    }
                }
            }
        }
        
    }
    
}

function wsconnect() {
    "use strict";
    wsuri = "ws://" + node_ip;
    if (window.hasOwnProperty("WebSocket")) {
        sock = new WebSocket(wsuri);
    } else {
        log("Browser does not support WebSocket!");
    }
    if (sock) {
        sock.onopen = function () {
            log("Connected to " + wsuri);
            fails = 0;
            if (token !== "") {
                setTimeout(function () {
                    sock.send(JSON.stringify({conf: {pass: token}}));
                }, 1000
                    );
                setTimeout(function () {
                    sock.send('{"conf": "{}"}');
                }, 2000
                          );
            }
        };
        sock.onclose = function (e) {
            log("Connection closed (wasClean = " + e.wasClean + ", code = " + e.code + ", reason = '" + e.reason + "')");
            fails += 1;
            if (fails > 10) {
                log("Max failure reached, Aborting");
                sock = null;
                window.location = "index.html";
            } else {
                wsconnect();
            }
        };
        sock.onmessage = function (e) {
            log("Got echo: " + e.data);
            var data = JSON.parse(e.data), key, el, k, secure;
            for (key in data) {
                if (data.hasOwnProperty(key)) {
                    if (key !== "") {
                      //log(key + ": " + data[key])
                        el = document.getElementById(key);
                        if (el !== null) {
                            if (data[key] === -1) {
                                document.getElementById(key).innerHTML = "NA";
                            } else {
                                document.getElementById(key).value = data[key];
                            }
                        } else {
                            if (key === "auth" && data[key] === true) {
                                log("authenticated");

                            }
                            if (key === "wifi_scan") {
                                log("ouais!!!!");
                                for (k in data[key]) {
                                    if (data[key].hasOwnProperty(k)) {
                                        log(k);
                                        secure = false;
                                        if (arRssi.indexOf(data[key][k][0]) < 0) {
                                            arRssi.push(data[key][k][0]);
                                        }
                                        aps[k] = [data[key][k][0], data[key][k][1]];
                                    }
                                }
                                update_wifi_widget();
                            }
                        }
                    }
                }
            }
        };
        sock.onerror = function (e) {
            log("Got error: " + e.data);
        };
    }
}

function show_settings() {
    "use strict";
    if (admin === false) {
        document.getElementById("popup").style.display = "block";
        document.getElementById("overlay").style.display = "block";

    }
}

window.onload = function () {
    "use strict";
    cryptoObj = window.crypto || window.msCrypto; // for IE 11
    ellog = document.getElementById('log');
    node_ip = window.location.hostname;
//     if (sessionStorage.node_ip) {
//         node_ip = sessionStorage.node_ip;
//     } else {
//         window.location = "index.html";
//     }
    if (sessionStorage.pwd) {
        token = sessionStorage.pwd;
        log(token);
        wsconnect();
    } else {
        show_settings();
    }
};

function hex(buffer) {
    "use strict";
    var hexCodes = [], view = new DataView(buffer), i, value, padding,
        paddedValue, stringValue;
    for (i = 0; i < view.byteLength; i += 4) {
    // Using getUint32 reduces the number of iterations needed (we process 4 bytes each time)
        value = view.getUint32(i);
    // toString(16) will give the hex representation of the number without padding
        stringValue = value.toString(16);
    // We use concatenation and slice for padding
        padding = '00000000';
        paddedValue = (padding + stringValue).slice(-padding.length);
        hexCodes.push(paddedValue);
    }

  // Join all the hex strings into one
    return hexCodes.join("");
}

/*function sha256(str) {
  // We transform the string into an arraybuffer.
    "use strict";
    var buffer = new TextEncoder("utf-8").encode(str);
    return cryptoObj.subtle.digest("SHA-256", buffer).then(function (hash) {
        return hex(hash);
    });
}*/

function check_pass() {
    "use strict";
    document.getElementById("popup").style.display = "none";
    document.getElementById("overlay").style.display = "none";
    var password = document.getElementById("pass").value, res;
    console.log("1");
    // chrome fix ...
    res = sha256(password);
    sessionStorage.pwd = res;
    token = sessionStorage.pwd;
    wsconnect();
//    sha256(password).then(function (res) {
//        sessionStorage.pwd = res;
//        console.log("2");
//        token = sessionStorage.pwd;
//        wsconnect();
//    });
}

function wifi() {
    "use strict";
    arRssi = [];
    aps = {};
    sock.send('{"conf": {"wifi": {}}}');
}

function set_wifi() {
    "use strict";
    if (document.getElementById("wifikey").value === "") {
        sock.send('{"conf": {"wifi": {"ssid": "' + currAp + '"}}}');
    } else {
        sock.send('{"conf": {"wifi": {"ssid": "' + currAp + '", "pwd": "' + document.getElementById("wifikey").value + '"}}}');
    }
    setTimeout(wsconnect, 20);
    
}

function changed(id, value) {
    "use strict";
    log(id);
    log(value);
    if (!toSend.conf) {
        toSend.conf = {};
    }
    toSend.conf[id] = value;
    document.getElementById("apply").disabled = false;
    document.getElementById("cancel").disabled = false;
}

function send() {
    "use strict";
    log(JSON.stringify(toSend));
    sock.send(JSON.stringify(toSend));
    toSend = {};
}

function cancel() {
    "use strict";
    toSend = {};
    sock.send('{"conf": "{}"}');
}
