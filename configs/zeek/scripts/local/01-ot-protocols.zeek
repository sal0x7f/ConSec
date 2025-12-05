# lightweight Zeek script to log Modbus-like connections and suspicious payloads
module ConsecOT;

export {
    redef enum Log::ID += { OT_MODBUS };
}

event zeek_init()
{
    Log::create_stream(ConsecOT::OT_MODBUS, [$columns=Info, $path="ot_modbus"]);
}

type Info: record {
    ts: time &log;
    id: string &log;
    src: addr &log;
    dst: addr &log;
    src_port: port &log;
    dst_port: port &log;
    note: string &log;
};

event tcp_packet(c: connection, is_orig: bool, seq: count, pkt: string)
{
    # scan for Modbus/TCP port 502 or signatures
    if (c$id$resp_p == 502 || c$id$orig_p == 502)
    {
        local info: Info = [$ts=network_time(), $id=c$id$orig_h + ":" + c$id$resp_h, $src=c$id$orig_h, $dst=c$id$resp_h, $src_port=c$id$orig_p, $dst_port=c$id$resp_p, $note="modbus-port-traffic"];
        Log::write(ConsecOT::OT_MODBUS, info);
    }
}
}