#ifndef SOCKET_H
#define SOCKET_H

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <string>
#include <arpa/inet.h>


const int MAX_CONNECTIONS = 1;
const int MAX_RECV = 1024;
const int MAX_HOSTNAME = 255;

class Socket {
  public:
    Socket();
    virtual ~Socket();

    bool init();
    void close();

    bool connect( const std::string host, const int port );

    bool bind( const int port );
    bool listen() const;
    bool accept( Socket & ) const;

    bool send( const std::string& ) const;
    int recv( std::string& ) const;

    void set_non_blocking( const bool );

  private:
    int m_socket;
    sockaddr_in m_address;
};

#endif
