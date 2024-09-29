import javax.imageio.ImageIO;
import java.io.*;
import java.awt.image.BufferedImage;

public class ToBitmap {
	public static void main(String[] args) {
		try {
			BufferedImage img = ImageIO.read(new File(args[0]));
			BufferedWriter bw = new BufferedWriter(new FileWriter(new File("bitmap.asm")));
			for(int i = 0; i < 480; i++) {
				for(int j = 0; j < 100; j++) {
					int val = 0;
					for(int k = 0; k < 8; k++) {
						int rgb = img.getRGB(j * 8 + k, i);
						rgb &= 0xFF;
						val <<= 1;
						if(rgb >= 128) val |= 1;
					}
					if(j % 10 == 0) {
						bw.newLine();
						bw.write("db ");
					}
					bw.write(String.format("0x%02x", val));
					if((j + 1) % 10 != 0) bw.write(",");
				}
			}
			bw.close();
		}catch(Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
