#include "Socket.h"
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <iostream>

Socket::Socket() 
{
  m_socket = -1;
  memset( &m_address, 0, sizeof( m_address ));
}

Socket::~Socket()
{
  if( m_socket >= 0 ) {
    ::close( m_socket );
  }
}

bool Socket::init()
{
  if( (m_socket = socket( AF_INET, SOCK_STREAM, 0 )) == -1)
    return false;

  // deal with TCP state TIME_WAIT
  int one = 1;
  if ( setsockopt( m_socket, SOL_SOCKET, SO_REUSEADDR, ( const char* ) &one, sizeof(one)) == -1)
    return false;

  return true;
}

bool Socket::bind( const int port )
{
  if ( m_socket == -1 )
    return false;

  m_address.sin_family = AF_INET;
  m_address.sin_addr.s_addr = INADDR_ANY;
  m_address.sin_port = htons ( port );

  if(::bind( m_socket, (struct sockaddr *)&m_address, sizeof(m_address)) == -1)
    return false;

  return true;
}

bool Socket::listen() const
{
  if ( m_socket == -1 )
    return false;

  if(::listen( m_socket, MAX_CONNECTIONS ) == -1)
    return false;

  return true;
}

bool Socket::accept( Socket& peer ) const
{
  int addr_len = sizeof ( m_address );
  peer.m_socket = ::accept ( m_socket, ( sockaddr * ) &m_address, ( socklen_t * ) &addr_len );

  if ( peer.m_socket < 0 )
    return false;

  return true;
}

bool Socket::send( const std::string &s ) const
{
  if(::send ( m_socket, s.c_str(), s.size(), MSG_NOSIGNAL ) == -1)
    return false;

  return true;
}

int Socket::recv( std::string& s ) const
{
  char buf[MAX_RECV + 1];

  s = "";

  memset( buf, 0, MAX_RECV+1 );

  int status = ::recv( m_socket, buf, MAX_RECV, 0);

  if( status == -1 ) {
      if ( errno == EAGAIN )
	return 0;

      return -1;
  }
  else if ( status == 0 )
      return -1;
  else {
      s = buf;
      return status;
  }
}

bool Socket::connect( const std::string host, const int port )
{
  if( m_socket == -1 )
    return false;

  m_address.sin_family = AF_INET;
  m_address.sin_port = htons ( port );

  int status = inet_pton ( AF_INET, host.c_str(), &m_address.sin_addr );

  if ( errno == EAFNOSUPPORT ) return false;

  status = ::connect( m_socket, (sockaddr*)&m_address, sizeof(m_address));

  if (status < 0)
    return false;

  return true;
}

void Socket::set_non_blocking( const bool b )
{

  int opts;

  opts = fcntl ( m_socket, F_GETFL );

  if( opts < 0 )
    return;

  if( b )
    opts = (opts | O_NONBLOCK);
  else
    opts = (opts & ~O_NONBLOCK);

  fcntl( m_socket, F_SETFL, opts );
}

void Socket::close()
{
  if( m_socket == -1 )
    return;

  ::close(m_socket);
  m_socket = -1;
}
