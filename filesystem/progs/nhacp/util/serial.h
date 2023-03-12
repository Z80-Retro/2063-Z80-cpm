//
//    You should have received a copy of the GNU Lesser General Public
//    License along with this library; if not, write to the Free Software
//    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
//    USA
//
//
//****************************************************************************

#include <termios.h>


void setControlLines(int port, int dtr, int rts);
void initPort(int p, speed_t speed);
int readChar(int port);
void sendChar(int port, char ch);
void doStream(int port);
