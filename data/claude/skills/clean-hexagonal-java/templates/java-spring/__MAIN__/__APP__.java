package {{BASE_PACKAGE}};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class {{APP_CLASS}} {

    public static void main(String[] args) {
        SpringApplication.run({{APP_CLASS}}.class, args);
    }
}
