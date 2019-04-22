FROM php:7.3
COPY phpbench.php /
CMD ["php", "/phpbench.php"]
