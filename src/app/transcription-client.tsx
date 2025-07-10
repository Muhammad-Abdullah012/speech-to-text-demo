"use client";

import { useRef, useState } from "react";
import { createClient, ListenLiveClient, SOCKET_STATES } from "@deepgram/sdk";
import { toast } from "sonner";

export default function TranscriptionClient() {
  const [transcript, setTranscript] = useState("");
  const [isListening, setIsListening] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const socketRef = useRef<ListenLiveClient>(null);

  const getTemporaryKey = async () => {
    try {
      const response = await fetch("/api/get-token");
      if (!response.ok) {
        throw new Error(`Failed to fetch token: ${response.statusText}`);
      }
      const data = await response.json();
      return data.access_token;
    } catch (error) {
      console.error(error);
      toast.error("Could not get Deepgram token.");
      return null;
    }
  };

  const startListening = async () => {
    if (isListening || isLoading) return;

    setIsLoading(true);
    try {
      const tempKey = await getTemporaryKey();
      if (!tempKey) return;

      const _deepgram = createClient({ accessToken: tempKey });
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;

      const socket = _deepgram.listen.live({
        model: "nova-2",
        smart_format: true,
      });

      socketRef.current = socket;

      socket.on("open", () => {
        console.log("Connected to Deepgram WebSocket");
        mediaRecorder.start(250); // send audio every 250ms
        setIsListening(true);
        setIsLoading(false);
      });

      socket.on("Results", (data) => {
        const result = data.channel?.alternatives?.[0]?.transcript;
        if (result) {
          setTranscript((prev) => prev + result + " ");
        }
      });

      socket.on("error", (e) => {
        console.error("Deepgram socket error:", e);
        toast.error("Streaming error.");
        stopListening();
      });

      socket.on("close", () => {
        console.log("WebSocket closed");
        setIsListening(false);
      });

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0 && socket.getReadyState() === SOCKET_STATES.open) {
          socket.send(e.data);
        }
      };
    } catch (err) {
      console.error("Failed to start listening:", err);
      toast.error("Could not access microphone.");
      setIsLoading(false);
    }
  };

  const stopListening = () => {
    if (!isListening) return;

    try {
      mediaRecorderRef.current?.stop();
      streamRef.current?.getTracks().forEach((t) => t.stop());

      if (socketRef.current) {
        socketRef.current.send(JSON.stringify({ type: "CloseStream" }));
        socketRef.current.disconnect();
      }

      setIsListening(false);
    } catch (err) {
      console.error("Failed to stop listening:", err);
      toast.error("Error while stopping stream.");
    }
  };

  const downloadTranscript = () => {
    const element = document.createElement("a");
    const file = new Blob([transcript], { type: "text/plain" });
    element.href = URL.createObjectURL(file);
    element.download = "transcription.txt";
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
  };

  const clearTranscript = () => {
    setTranscript("");
  };

  return (
    <div className="max-w-xl w-full flex flex-col gap-6 items-center text-center px-4 sm:px-0">
      <div className="flex flex-col sm:flex-row gap-4 w-full justify-center">
        <button
          onClick={startListening}
          disabled={isListening || isLoading}
          className="w-full sm:w-auto px-6 py-3 rounded-full bg-green-600 text-white text-sm font-medium hover:bg-green-700 disabled:opacity-50 transition-all"
        >
          ▶️ Start Listening
        </button>

        <button
          onClick={stopListening}
          disabled={!isListening}
          className="w-full sm:w-auto px-6 py-3 rounded-full bg-red-600 text-white text-sm font-medium hover:bg-red-700 disabled:opacity-50 transition-all"
        >
          ⏹️ Stop Listening
        </button>

        <button
          onClick={clearTranscript}
          disabled={!transcript}
          className="w-full sm:w-auto px-6 py-3 rounded-full bg-gray-500 text-white text-sm font-medium hover:bg-gray-600 disabled:opacity-50 transition-all"
        >
          🧹 Clear
        </button>
      </div>

      <textarea
        value={transcript}
        onChange={(e) => setTranscript(e.target.value)}
        rows={10}
        readOnly
        className="w-full p-4 border border-gray-300 rounded-lg text-sm font-mono shadow-sm focus:outline-none focus:ring-2 focus:ring-black resize-none"
        placeholder="Live transcription will appear here..."
      />

      <button
        onClick={downloadTranscript}
        disabled={!transcript}
        className="w-full sm:w-auto px-6 py-3 rounded-full bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 transition-all"
      >
        💾 Download Transcript
      </button>
    </div>
  );
}
