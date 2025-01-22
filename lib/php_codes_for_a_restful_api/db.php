<?php
$host = 'sql110.infinityfree.com'; // or your host
$dbname = 'if0_37150274_my_school_management_system'; // your database name
$username = 'if0_37150274'; // your MySQL username
$password = '9WPa1JOg1TWefR'; // your MySQL password

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo 'Connection failed: ' . $e->getMessage();
}
?>
