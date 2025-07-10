import {
  createClient as createDeepgramClient,
  DeepgramClient,
} from "@deepgram/sdk";
import { NextResponse } from "next/server";

const getTempToken = async (deepgram: DeepgramClient) => {
  const { result, error } = await deepgram.auth.grantToken();

  if (error) {
    throw error;
  }

  return result;
};

export async function GET() {
  const deepgramApiKey = process.env.DEEPGRAM_API_KEY;

  if (!deepgramApiKey) {
    return NextResponse.json(
      { error: "DEEPGRAM_API_KEY is not configured in your environment." },
      { status: 500 }
    );
  }

  const deepgram = createDeepgramClient(deepgramApiKey);
  try {
    return NextResponse.json(await getTempToken(deepgram));
  } catch (error) {
    console.error("An unexpected error occurred:", error);
    return NextResponse.json(
      { error: "Failed to create temporary key." },
      { status: 500 }
    );
  }
}
