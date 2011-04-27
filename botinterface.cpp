#include "botinterface.h"
#include "snoutlib/misc.h"
#include <sstream>

BotInterface::BotInterface() :
 m_listen_socket(2101)
{
    m_listen_socket.set_non_blocking(true);
}

BotInterface::~BotInterface()
{
    if(m_connected)
        m_client_socket.close();
}
/** @brief async_accept
  *
  * Run a non-blocking call to accept one incoming bot connection.
  */
bool BotInterface::async_accept()
{
    if(!m_connected && m_listen_socket.accept(m_client_socket)) {
        m_client_socket.set_non_blocking(true);
        m_connected = true;
        return true;
    }
    return false;
}

/** @brief async_read
  *
  * read a line from the bot, if available.
  * disconnect bot if any error occurs, unless there is no data available.
  */
bool BotInterface::async_read(std::string &msg)
{
  if(!m_connected)
    return false;

  int status = m_client_socket.recv(msg);
  if(status > 0) {
    return true;
  } else if(status < 0) {
    m_client_socket.close();
    m_connected = false;
  }
  return false;
}

/** @brief async_send
  *
  * send a line to the bot.
  * disconnect bot on any error.
  */
bool BotInterface::async_send(float time, std::string event, vec2 pos, std::string params)
{
    if(!m_connected)
        return false;

    // format message and send

    stringstream msg;
    msg << time << " " << pos[0] << "," << pos[1] << " " << event << " " << params << std::endl;

    if(!m_client_socket.send(msg.str())) {
        m_client_socket.close();
        m_connected = false;
        return false;
    }
    return true;
}
