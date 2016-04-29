#include <Bridge.h>
#include <Console.h>
#include <Wire.h>
#include <YunServer.h>
#include <YunClient.h>
#include <Servo.h>

String command = "none";
String device = "none";
String value = "none";
String maybe = "none";

Servo xServo;  // create servo object to control a servo
Servo yServo;  // create servo object to control a servo

int speedPin = 3;
int steeringPin = 5;
int xServoPin = 9;
int yServoPin = 6;

// We open the socket 5678 to communicate.
YunServer server(5678);

void setup() {
  Serial.begin(9600);

  // Bridge startup
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
  Bridge.begin();
  digitalWrite(13, HIGH);

  server.noListenOnLocalhost();
  server.begin();
  
  xServo.attach(xServoPin);
  yServo.attach(yServoPin);

  xServo.write(90);
  yServo.write(75);
  analogWrite(speedPin, 1);
  analogWrite(steeringPin, 198.9);

}

void loop() {
  uint8_t i;
  YunClient client = server.accept();
  // There is a new client?
  if (client) {
    Serial.println("found client");
    client.setTimeout(5);
    while (!command.equals("stop") && client.connected()) {
      if (client.available() > 0) {
        device = client.readStringUntil('/');
        value = client.readStringUntil('/');
        //Serial.println(device + " , " + value);
        if (device.equals("x")) {
          Serial.println("xServo: " + value);
          //xServo.write(value.toInt());
        }
        else if (device.equals("y")) {
          yServo.write(value.toInt());
          //Serial.println("yservo: " + value);
        }
        else if (device.equals("d")) {
          analogWrite(speedPin, value.toInt());
          //Serial.println("speed: " + value);
        }
        else if (device.equals("s")) {
          analogWrite(steeringPin, value.toInt());
          //Serial.println("steering: " + value);
        }
      }
    }
    digitalWrite(13, HIGH);
    Serial.println("stopping");
    command = "";
    client.stop();
    xServo.write(90);
    yServo.write(75);
    analogWrite(speedPin, 1);
    analogWrite(steeringPin, 198.9);
  }
  else {
    //Serial.println("no client found");
  }
}
