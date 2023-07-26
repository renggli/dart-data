/// Resolves a negative index to be counted from the end of the list.
int adjustIndex(int index, int length) => index < 0 ? index + length : index;
