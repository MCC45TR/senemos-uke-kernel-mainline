# Source-only spec transformation. Retain every legacy gate before the new
# postimage is compiled, then finish %build in the same kernel directory.
$0 == "bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} prepared" {
 print
 print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} prepared"
 prepared++
 next
}
$0 == "%install" {
 print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} objects"
 print
 objects++
 next
}
{ print }
END { if (prepared != 1 || objects != 1) exit 1 }
