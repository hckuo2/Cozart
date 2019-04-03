<html>
<head>
    <title>PHP Test</title>
</head>
    <body>
<?php echo '<p>Hello World</p>';

// In the variables section below, replace user and password with your own MySQL credentials as created on your server
$servername = "localhost";
$username = "root";
$password = "root";

// Create MySQL connection
$conn = mysqli_connect($servername, $username, $password);

// Check connection - if it fails, output will include the error message
if (!$conn) {
    die('<p>Connection failed: <p>' . mysqli_connect_error());
}
echo '<p>Connected successfully</p>';
?>
</body>
</html>

