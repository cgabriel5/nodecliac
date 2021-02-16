from math import floor
from times import getTime, toUnix

# Finds the 'timeago' of provided timestamp.
#
# @param {int|float} timestamp - The given data type.
# @return {string} - The timeago string
# @resource [https://stackoverflow.com/a/3177838]
# @resource [https://stackoverflow.com/a/847196]
# @resource [https://coderrocketfuel.com/article/convert-a-unix-timestamp-to-a-date-in-vanilla-javascript]
proc timeago*(timestamp: int|int64): string =
    let timestamp = timestamp.int
    let curtime = getTime().toUnix().int

    let seconds = (curtime - timestamp)
    if seconds == 0: return "0 seconds"

    var interval = (seconds/31536000)
    proc int2str(n: int|float): string = $(floor(n.float).int)

    if interval > 1: return int2str(interval) & " years"
    interval = seconds/2592000
    if interval > 1: return int2str(interval) & " months"
    interval = seconds/86400
    if interval > 1: return int2str(interval) & " days"
    interval = seconds/3600
    if interval > 1: return int2str(interval) & " hours"
    interval = seconds/60
    if interval > 1: return int2str(interval) & " minutes"
    return int2str(seconds) & " seconds"

# var timestamp = getTime().toUnix()
# echo timeago(timestamp)
# echo timeago(1613428276)
# echo timeago(1613378187)
