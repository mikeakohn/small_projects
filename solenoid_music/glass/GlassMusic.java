import net.mikekohn.java_grinder.CPU;
import net.mikekohn.java_grinder.IOPort0;
import net.mikekohn.java_grinder.IOPort1;
import net.mikekohn.java_grinder.Timer;
import net.mikekohn.java_grinder.TimerListener;

// 2,000,000 cycles * 0.001 = 2000 cycles
// 1000 interrupts = 1s

public class GlassMusic implements TimerListener
{
  public static int interrupt_count = 0;

  public static final int D4 = 0;
  public static final int E4 = 1;
  public static final int G4 = 2;
  public static final int A4 = 3;
  public static final int D5 = 4;
  public static final int E5 = 5;
  public static final int FS5 = 6;
  public static final int G5 = 7;

  public static int[] note_map =
  {
    0x00, 0x01,
    0x00, 0x02,
    0x00, 0x04,
    0x00, 0x08,
    0x00, 0x10,
    0x00, 0x20,
    0x20, 0x00,
    0x10, 0x00,
  };

  public static byte[] test =
  {
    D4, E4, G4, A4, D5, E5, FS5, G5
  };

  public static byte[] song =
  {
    D4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,

    D4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,

    D4, D5, A4, G4, G5, A4, FS5, A4,
    D4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    E4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    G4, D5, A4, G4, G5, A4, FS5, A4,
    E5, A4, D5, A4, E5, A4, FS5, A4,
    G5, A4, FS5, A4, E5, D5
  };

  public static void waitOneSecond()
  {
    // Spinning for 20,000 interrupts is 1 second.
    // The song file is a little off though.
    interrupt_count = 0;
    while (interrupt_count != 1000);
  }

  public static void waitForRelease()
  {
    interrupt_count = 0;
    while (interrupt_count != 30);
  }

  public static void waitForNote()
  {
    interrupt_count = 0;
    while (interrupt_count != 220);
  }

  public static void playSong()
  {
    int i;

    for (i = 0; i < song.length; i++)
    {
      int note = song[i] << 1;

      IOPort0.setPinsHigh(note_map[note + 0]);
      IOPort1.setPinsHigh(note_map[note + 1]);

      waitForRelease();

      IOPort0.setPinsLow(0x30);
      IOPort1.setPinsLow(0x3f);

      waitForNote();
    }
  }

  public static void waitForPlay()
  {
    while (true)
    {
      int buttons = IOPort0.getPortInputValue();

      if ((buttons & 0x01) == 0) { return; }
    }
  }

  public static void main(String args)
  {
    CPU.setClock2();

    // P1.0 = Play Button
    // P1.1 = Debug LED
    // P2.0 = Note 0
    // P2.1 = Note 1
    // P2.2 = Note 2
    // P2.3 = Note 3
    // P2.4 = Note 4
    // P2.5 = Note 5
    // P1.5 = Note 6
    // P1.4 = Note 7
    IOPort0.setPinsAsOutput(0x32);
    IOPort0.setPinsLow(0xff);
    IOPort0.setPinsHigh(0x01);
    IOPort0.setPinsResistorEnable(0x01);
    IOPort1.setPinsAsOutput(0x3f);
    IOPort1.setPinsLow(0x3f);

    // Setup timer interrupt (aka, Java listener).
    Timer.setInterval(2000, 1);
    Timer.setListener(true);

    while (true)
    {
      // Poll buttons.
      waitForPlay();

      IOPort0.setPinsHigh(0x02);
      waitOneSecond();

      // Send commands to start song.
      playSong();
      IOPort0.setPinsLow(0x02);
    }
  }

  public void timerInterrupt()
  {
    interrupt_count++;
  }
}

