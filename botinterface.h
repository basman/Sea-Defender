#pragma once

#include "netlib/Socket.h"
#include "netlib/ServerSocket.h"
#include "snoutlib/misc.h"
#include <string>

class BotInterface
{
    public:
        BotInterface();
        virtual ~BotInterface();
        bool is_connected() { return m_connected; }
        bool async_accept();
        bool async_send(float time, string event, vec2 pos=vec2(0,0), string params="");
        bool async_read(string &msg);
    protected:
    private:
        bool m_connected;
        ServerSocket m_listen_socket;
        Socket m_client_socket;
};
