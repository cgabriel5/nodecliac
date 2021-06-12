#include <cxxopts.hpp> // [https://github.com/jarro2783/cxxopts]
#include <iostream>
using namespace std;

int main(int argc, char **argv) {

	if (argc == 1) exit(1);

	cxxopts::Options options("", "");

	options
		// [https://github.com/jarro2783/cxxopts/pull/105]
		.allow_unrecognised_options()
		.add_options()
			("igc", "",    cxxopts::value<bool>()->default_value("false"))
			("test", "",   cxxopts::value<bool>()->default_value("false"))
			("print", "",  cxxopts::value<bool>()->default_value("false"))
			("trace", "",  cxxopts::value<bool>()->default_value("false"))
			("action", "", cxxopts::value<std::string>())
			("indent", "", cxxopts::value<std::string>()->default_value("s:4"))
			("source", "", cxxopts::value<std::string>()->default_value(""))
			("positional", "", cxxopts::value<std::vector<std::string>>());
	options.parse_positional({"action", "positional"});
	auto result = options.parse(argc, argv);

	bool igc = result["igc"].as<bool>();
	bool test = result["test"].as<bool>();
	bool print = result["print"].as<bool>();
	bool trace = result["trace"].as<bool>();
	std::string action;
	std::string indent;
	std::string source;
	if (result.count("action")) action = result["action"].as<std::string>();
	if (result.count("indent")) indent = result["indent"].as<std::string>();
	if (result.count("source")) source = result["source"].as<std::string>();
	bool formatting = action == "format";

	return 0;

}
