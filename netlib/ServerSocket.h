#ifndef SERVERSOCKET_H
#define SERVERSOCKET_H

#include "Socket.h"

class ServerSocket : private Socket
{
 public:

  ServerSocket ( int port );
  ServerSocket () {};
  virtual ~ServerSocket();

  bool accept( Socket& );
  void set_non_blocking( const bool noblock ) { Socket::set_non_blocking(noblock); };
  void close() { Socket::close(); };
};

#endif
