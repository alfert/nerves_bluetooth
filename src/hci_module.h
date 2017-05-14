#ifndef HCI_MODULE
#define HCI_MODULE


#define bool char
#define true 1
#define false 0

#ifdef DEBUG
#define LOG(...) flog(__VA_ARGS__)
#else
#define LOG(fmt, ...)
#endif

/* Logging function, not part of the API */
void flog(const char *fmt, ...);

/* hci_init() 
 * Opens the HCI Socket for the Bluetooth Controller
 * returns: true if no problem occurs
 */
bool hci_init();

/* hci_close() 
 * Closes the HCI Socket for the Bluetooth Controller
 * returns: 0 if no problem occurs
 */
int hci_close();

/* hci_dev_id_for()
 * Resolves the devices ID, depending on the device state.
 */
int hci_dev_id_for(int* p_dev_id, bool is_up);   

/* hci_is_dev_up
 * Is the current device already up? 
 */
bool hci_is_dev_up();

/** int hci_bind_raw(int *dev_id)
 * Binds the raw socket and starts listening to events
 */
int hci_bind_raw(int *dev_id);

/* int hci_write(byte *data, int size)
 * Write the data to the hci socket, returns the result of write
 */
int hci_write(byte *data, int size);

/* int hci_set_filter(byte *data, int size)
 * Set the filter for events propagation
*/
int hci_set_filter(byte *data, int size);

/* Testing function, from the tutorial */
int hci_foo(int x);


#endif
