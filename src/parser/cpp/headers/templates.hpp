#include <string>
#include <array>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include <iterator>

using namespace std;

// [https://stackoverflow.com/a/28097056]
// [https://stackoverflow.com/a/43823704]
// [https://stackoverflow.com/a/1701083]
// [https://www.techiedelight.com/find-index-element-array-cpp/]
template <typename T, typename V>
bool contains(T const &container, V const &value) {
	auto it = find(container.begin(), container.end(), value);
	return (it != container.end());
}

template <typename T, typename V>
bool hasKey(T const &map, V const &value) {
	// [https://stackoverflow.com/a/3136545]
	auto it = map.find(value);
	return (it != map.end());
}

// [https://stackoverflow.com/a/23242922]
// [https://www.delftstack.com/howto/cpp/remove-element-from-vector-cpp/]
// [https://iq.opengenus.org/ways-to-remove-elements-from-vector-cpp/]
template <typename T, typename V>
void remove(vector<T> &v, const V &value) {
	v.erase(remove(v.begin(), v.end(), value), v.end());
}
