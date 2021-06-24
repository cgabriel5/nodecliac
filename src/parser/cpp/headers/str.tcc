// [https://stackoverflow.com/a/10632266]
template<size_t N>
string join(array<string, N> &container, const string &delimiter) {
	string buffer = "";
	int size = container.size();
	for (int i = 0; i < size; i++) {
		buffer += container[i];
		// [https://stackoverflow.com/a/611352]
		if (i + 1 < size) buffer += delimiter;
	}
	return buffer;
}
