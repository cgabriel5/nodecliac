/**
 * Make the provided array unique.
 *
 * @param  {array} array - The array to clean.
 * @param  {boolean} flag_sort - Flag indicating whether the array needs to be sorted.
 * @return {array} - The worked on array.
 *
 * @resource [http://stackoverflow.com/questions/1960473/unique-values-in-an-array/39272981#39272981]
 * @ersource [http://stackoverflow.com/questions/1063007/how-to-sort-an-array-of-integers-correctly/21595293#21595293]
 */
module.exports = (array, flag_sort) => {
	// Make array unique.
	array = array.filter(function(x, i, a_) {
		return a_.indexOf(x) === i;
	});

	// Sort the array if flag set.
	// **Note: does not sort numbers.
	if (flag_sort) {
		if (flag_sort === "alpha") {
			// [https://stackoverflow.com/a/16481400]
			array = array.sort(function(a, b) {
				return a.localeCompare(b);
			});
		} else if (flag_sort === "number") {
			array.sort(function(a, b) {
				return a - b;
			});
		}
	}

	// Return the array.
	return array;
};
