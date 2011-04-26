#include "ServerSocket.h"

ServerSocket::ServerSocket( int port )
{
  if( !Socket::init() )
    return; /* TODO should throw exception */

  if( !Socket::bind ( port ) )
    return; /* TODO should throw exception */

  if( !Socket::listen() )
    return; /* TODO should throw exception */
}

ServerSocket::~ServerSocket()
{
}

bool ServerSocket::accept( Socket& peer )
{
  return Socket::accept ( peer );
}
