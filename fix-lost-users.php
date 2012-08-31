<?php

/**
 * @file
 * Script to fix lost users after a crashed or broken database
 *
 * Requires affected users to sign up with the same name they were
 * previously using. It does not restore permissions, but gets you
 * MUCH closer than you were.
 *
 * Known to work on vBulletin 4.1.2
 */

// Be sure to configure these variables before you run it
$db = '';
$host = '';
$user = '';
$pass = '';

$link = mysql_connect($host, $user, $pass);
if (!$link) {
  die('Could not connect: ' . mysql_error());
}
echo "Connected successfully<br>";
$db_selected = mysql_select_db($db, $link);
if (!$db_selected) {
  die('Can\'t use ' . $db . ':' . mysql_error());
}
echo "Using DB {$db}<br>";

// Get users whose usernames match between the {user} table and the {post}
// table. The username columns aren't keys, so this query will take a LONG
// time. You may need to consider allowing PHP to execute forever.
$uquery = sprintf("SELECT DISTINCT u.username, u.userid AS newid, p.userid AS oldid, u.lastactivity
                   FROM user AS u
                   JOIN post AS p ON u.username = p.username
                   WHERE u.userid != p.userid
                   ORDER BY u.lastactivity DESC");
$users = mysql_query($uquery, $link);
if (!$users) {
  die('Invalid query: ' . mysql_error());
}
while($urow[] = mysql_fetch_array($users, MYSQL_ASSOC));

// Need to get an array of all tables that have a userid
$tquery = sprintf("SELECT DISTINCT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME IN ('%s') AND TABLE_SCHEMA='%s'", 'userid', $db);
$tables = mysql_query($tquery, $link);
if (!$tables) {
  die('Invalid query: ' . mysql_error());
}
while ($trow[] = mysql_fetch_array($tables, MYSQL_ASSOC));

// Loop over users, and while on each user we loop over every table that has a
// userid column.
foreach ($urow AS $user) {
  if (empty($user)) {
    continue;
  }
  echo "<strong>Fixing data for {$user['username']}</strong>...<br>";
  foreach ($trow AS $table) {
    if (empty($table)) {
      continue;
    }
    // This table will always error. No use in trying.
    if ($table['TABLE_NAME'] == 'user') {
      continue;
    }
    echo "Updating {$table['TABLE_NAME']}...<br>";
    $update = sprintf("UPDATE %s SET userid=%d WHERE userid=%d", $table['TABLE_NAME'], (int) $user['newid'], (int) $user['oldid']);
    echo $update . '<br>';
    $result = mysql_query($update, $link);
    if (!$result) {
      // Some tables related to profiles and user fields will error if the
      // userid must be unique, so some of these may be safe to ignore. As
      // always, TEST!
      echo "<em>Could not update table <strong>{$table['TABLE_NAME']}</strong></em><br>";
    }
  }
  // Update user post counts
  echo "Updating post count for {$user['username']}...<br>";
  $pcquery = sprintf("SELECT * FROM post WHERE userid=%d", (int) $user['newid']);
  echo $pcquery . '<br>';
  $pcresult = mysql_query($pcquery, $link);
  $postcount = mysql_num_rows($pcresult);
  $updatepc = sprintf("UPDATE user SET posts=%d WHERE userid=%d", (int) $postcount, (int) $user['newid']);
  echo $updatepc . '<br>';
  $pc = mysql_query($updatepc, $link);
  if (!$pc) {
    echo "<em>Could not update post count for {$user['username']}</em> to {$postcount}<br>";
  }
}

mysql_close($link);
